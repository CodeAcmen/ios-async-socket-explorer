//
//  TJPNetworkCoordinator.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPNetworkCoordinator.h"
#import <Reachability/Reachability.h>

#import "TJPNetworkConfig.h"
#import "TJPSessionDelegate.h"
#import "TJPSessionProtocol.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkDefine.h"
#import "TJPReconnectPolicy.h"



@interface TJPNetworkCoordinator () <TJPSessionDelegate>
@property (nonatomic, strong) TJPNetworkConfig *currConfig;

//上次报告的状态
@property (nonatomic, assign) NetworkStatus lastReportedStatus;


@end

@implementation TJPNetworkCoordinator 

#pragma mark - instance
+ (instancetype)shared {
    static TJPNetworkCoordinator *instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (instancetype)init {
    if (self = [super init]) {
        _sessionMap = [NSMapTable strongToStrongObjectsMapTable];
        [self setupQueues];
        [self setupNetworkMonitoring];
    }
    return self;
}

#pragma mark - Private Method
- (void)setupQueues {
    //串行队列,只处理会话
    _sessionQueue = dispatch_queue_create("com.networkCoordinator.tjp.sessionQueue", DISPATCH_QUEUE_SERIAL);
    //专用数据解析队列 并发高优先级
    _parseQueue = dispatch_queue_create("com.networkCoordinator.tjp.parseQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_set_target_queue(_parseQueue, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    //串行监控队列
    _monitorQueue = dispatch_queue_create("com.networkCoordinator.tjp.monitorQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_monitorQueue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
}

- (void)setupNetworkMonitoring {
    // 初始化网络监控
    self.reachability = [Reachability reachabilityForInternetConnection];
    
    __weak typeof(self) weakSelf = self;
    // 网络状态变更回调
    self.reachability.reachableBlock = ^(Reachability *reachability) {
        [weakSelf handleNetworkStateChange:reachability];
    };
    
    self.reachability.unreachableBlock = ^(Reachability *reachability) {
        [weakSelf handleNetworkStateChange:reachability];
    };
    
    [self.reachability startNotifier];
}

- (void)handleNetworkStateChange:(Reachability *)reachability {
    NetworkStatus status = [reachability currentReachabilityStatus];
    
    dispatch_async(self.monitorQueue, ^{
        // 检查状态是否有变化
        if (status == self.lastReportedStatus && self.lastReportedStatus != NotReachable) {
            // 如果状态相同且不是不可达状态，不重复处理
            return;
        }
        
        // 更新状态
        NetworkStatus oldStatus = self.lastReportedStatus;
        self.lastReportedStatus = status;
        
        // 记录状态变化
        TJPLOG_INFO(@"网络状态变更: %d -> %d", (int)oldStatus, (int)status);
        
        // 发送全局网络状态通知
        [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkStatusChangedNotification
                                                          object:self
                                                        userInfo:@{@"status": @(status)}];
        
        switch (status) {
            case NotReachable:
                TJPLOG_INFO(@"网络不可达，断开所有会话连接");
                [self notifySessionsOfNetworkStatus:NO];
                break;
                
            case ReachableViaWiFi:
            case ReachableViaWWAN:
                TJPLOG_INFO(@"网络恢复，尝试自动重连");
                // 如果是从不可达状态变为可达状态，则进行连通性验证
                if (oldStatus == NotReachable) {
                    [self verifyNetworkConnectivity:^(BOOL isConnected) {
                        if (isConnected) {
                            TJPLOG_INFO(@"网络连通性验证成功，尝试自动重连");
                            dispatch_async(self.monitorQueue, ^{
                                [self notifySessionsOfNetworkStatus:YES];
                            });
                        } else {
                            TJPLOG_INFO(@"网络报告可达但实际不通，暂不重连");
                            // 可选：延迟再次尝试
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), self.monitorQueue, ^{
                                [self handleNetworkStateChange:reachability];
                            });
                        }
                    }];
                } else {
                    // 如果只是WiFi和移动网络之间的切换，直接通知
                    [self notifySessionsOfNetworkStatus:YES];
                }
                break;
        }
    });
}

- (void)verifyNetworkConnectivity:(void(^)(BOOL isConnected))completion {
    // 避免在主线程上执行网络请求
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        // 选择一个稳定、响应快的服务进行连通性检测
        NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url
                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                            timeoutInterval:5.0];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                BOOL isConnected = NO;
                
                if (error == nil) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                    isConnected = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300);
                }
                
                TJPLOG_INFO(@"网络连通性检测结果: %@", isConnected ? @"可连接" : @"不可连接");
                
                // 在主队列回调
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(isConnected);
                    });
                }
            }];
        
        [task resume];
    });
}




- (void)handleSessionDisconnection:(id<TJPSessionProtocol>)session {
    if (!session) {
        TJPLOG_ERROR(@"处理断开连接的会话为空");
        return;
    }
    TJPDisconnectReason reason = [(TJPConcreteSession *)session disconnectReason];
    NSString *sessionId = session.sessionId;
    

    // 使用全局队列处理重连逻辑，避免阻塞主要队列
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            // 根据断开原因决定下一步操作
            switch (reason) {
                case TJPDisconnectReasonNetworkError:
                case TJPDisconnectReasonHeartbeatTimeout:
                case TJPDisconnectReasonIdleTimeout:
                    // 这些原因是需要尝试重连的
                    TJPLOG_INFO(@"会话 %@ 因 %@ 断开，尝试自动重连", sessionId, [self reasonToString:reason]);
                    [self scheduleReconnectForSession:session];
                    break;
                    
                case TJPDisconnectReasonUserInitiated:
                case TJPDisconnectReasonForceReconnect:
                    // 这些原因是不需要重连的，应直接移除会话
                    TJPLOG_INFO(@"会话 %@ 因 %@ 断开，不会重连", sessionId, [self reasonToString:reason]);
                    [self removeSession:session];
                    break;
                    
                case TJPDisconnectReasonSocketError: {
                    // 服务器关闭连接，需要根据业务策略决定是否重连
                    TJPLOG_WARN(@"会话 %@ 因套接字错误断开，检查是否重连", sessionId);

                    // 获取会话配置，决定是否重连
                    TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
                    if (concreteSession.config.shouldReconnectAfterServerClose) {
                        [self scheduleReconnectForSession:session];
                    } else {
                        [self removeSession:session];
                    }
                    break;
                }
                    
                case TJPDisconnectReasonAppBackgrounded: {
                    // 应用进入后台，根据配置决定是否保持连接
                    TJPLOG_INFO(@"会话 %@ 因应用进入后台而断开", sessionId);
                    TJPConcreteSession *concreteSessionBackground = (TJPConcreteSession *)session;
                    if (concreteSessionBackground.config.shouldReconnectAfterBackground) {
                        // 标记为需要在回到前台时重连
//                        concreteSessionBackground.needsReconnectOnForeground = YES;
                    } else {
                        [self removeSession:session];
                    }
                    break;
                }
                default:
                    TJPLOG_WARN(@"会话 %@ 断开原因未知: %d，默认不重连", sessionId, (int)reason);
                    [self removeSession:session];
                    break;
            }
        });
}

- (NSString *)reasonToString:(TJPDisconnectReason)reason {
    switch (reason) {
        case TJPDisconnectReasonNone:
            return @"默认状态";
        case TJPDisconnectReasonUserInitiated:
            return @"用户手动断开";
        case TJPDisconnectReasonNetworkError:
            return @"网络错误";
        case TJPDisconnectReasonHeartbeatTimeout:
            return @"心跳超时";
        case TJPDisconnectReasonIdleTimeout:
            return @"空闲超时";
        case TJPDisconnectReasonSocketError:
            return @"套接字错误";
        case TJPDisconnectReasonForceReconnect:
            return @"强制重连";
        default:
            return @"未知原因";
    }
    
}

- (NSArray *)safeGetAllSessions {
    __block NSArray *sessions;
    dispatch_sync(self->_sessionQueue, ^{
        sessions = [[_sessionMap objectEnumerator] allObjects];
    });
    return sessions;
}

//安全获取单个会话的方法
- (id<TJPSessionProtocol>)safeGetSessionWithId:(NSString *)sessionId {
    __block id<TJPSessionProtocol> session = nil;
    dispatch_sync(self->_sessionQueue, ^{
        session = [self.sessionMap objectForKey:sessionId];
    });
    return session;
}

//获取当前会话总数
- (NSUInteger)sessionCount {
    __block NSUInteger count = 0;
    dispatch_sync(self->_sessionQueue, ^{
        count = self.sessionMap.count;
    });
    return count;
}


#pragma mark - Notification
- (void)notifySessionsOfNetworkStatus:(BOOL)available {
    NSArray *sessions = [self safeGetAllSessions];
    
    for (id<TJPSessionProtocol> session in sessions) {
        if (available) {
            // 通知会话网络恢复
            [session networkDidBecomeAvailable];
        } else {
            // 通知会话网络断开
            [session networkDidBecomeUnavailable];
        }
    }
}



#pragma mark - Public Method
- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config {
    _currConfig = config;
    TJPConcreteSession *session = [[TJPConcreteSession alloc] initWithConfiguration:config];
    session.delegate = self;
    dispatch_barrier_async(self->_sessionQueue, ^{
        [self.sessionMap setObject:session forKey:session.sessionId];
        
        TJPLOG_INFO(@"Session created: %@, total: %lu", session.sessionId, (unsigned long)self.sessionMap.count);
    });
    return session;
}


- (void)updateAllSessionsState:(TJPConnectState)state {
    dispatch_barrier_async(self->_sessionQueue, ^{
        NSEnumerator *enumerator = [self.sessionMap objectEnumerator];
        id<TJPSessionProtocol> session;
        
        while ((session = [enumerator nextObject])) {
            if ([session respondsToSelector:@selector(updateConnectionState:)]) {
                //事件驱动状态变更
                [session updateConnectionState:state];
            }
        }
    });
}

- (void)removeSession:(id<TJPSessionProtocol>)session {
    dispatch_barrier_async(self->_sessionQueue, ^{
        [self.sessionMap removeObjectForKey:session.sessionId];
        TJPLOG_INFO(@"Removed session: %@, remaining: %lu",  session.sessionId, (unsigned long)self.sessionMap.count);
    });
}

- (void)scheduleReconnectForSession:(id<TJPSessionProtocol>)session {
    dispatch_async(self->_sessionQueue, ^{
        TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
        
        // 只有特定原因的断开才尝试重连
        TJPDisconnectReason reason = concreteSession.disconnectReason;
        if (reason == TJPDisconnectReasonNetworkError ||
            reason == TJPDisconnectReasonHeartbeatTimeout ||
            reason == TJPDisconnectReasonIdleTimeout) {
            
            [concreteSession.reconnectPolicy attemptConnectionWithBlock:^{
                [concreteSession connectToHost:concreteSession.host port:concreteSession.port];
            }];
        }
    });
}



#pragma mark - TJPSessionDelegate
/// 接收到消息
- (void)session:(id<TJPSessionProtocol>)session didReceiveData:(NSData *)data {
    //分发处理
    [[NSNotificationCenter defaultCenter] postNotificationName:kSessionDataReceiveNotification object:@{@"session": session, @"data": data}];
}
/// 状态改变
- (void)session:(id<TJPSessionProtocol>)session stateChanged:(TJPConnectState)state {
    if ([state isEqualToString:TJPConnectStateDisconnected]) {
        [self handleSessionDisconnection:session];
    }
}


@end

