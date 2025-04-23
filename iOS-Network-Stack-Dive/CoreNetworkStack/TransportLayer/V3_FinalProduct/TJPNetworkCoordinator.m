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
    TJPDisconnectReason reason = [(TJPConcreteSession *)session disconnectReason];
    
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
//        if (reason == TJPDisconnectReasonNetworkError || reason == TJPDisconnectReasonIdleTimeout) {
//            TJPLOG_INFO(@"Session %@ marked for possible reconnect", session.sessionId);
//            [self.reconnectPolicy scheduleReconnectForSession:session];
//        } else {
//            TJPLOG_INFO(@"Session %@ removed due to intentional disconnect", session.sessionId);
//            [self removeSession:session];
//        }
//    });
}


- (NSArray *)safeGetAllSessions {
    __block NSArray *sessions;
    dispatch_sync(self->_sessionQueue, ^{  // 同步读取
        sessions = [[_sessionMap objectEnumerator] allObjects];
    });
    return sessions;
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

