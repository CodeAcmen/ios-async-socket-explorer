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
#import "TJPLightweightSessionPool.h"



@interface TJPNetworkCoordinator () <TJPSessionDelegate>
@property (nonatomic, strong) TJPNetworkConfig *currConfig;

//上次报告的状态
@property (nonatomic, assign) NetworkStatus lastReportedStatus;

//网络防抖
@property (nonatomic, strong) NSDate *lastNetworkChangeTime;
@property (nonatomic, assign) NSTimeInterval networkChangeDebounceInterval; // 默认设为2秒


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
        _networkChangeDebounceInterval = 2;
        _sessionMap = [NSMapTable strongToStrongObjectsMapTable];
        _sessionTypeMap = [NSMutableDictionary dictionary];
        _sessionPool = [TJPLightweightSessionPool sharedPool];
        
        // 初始化队列
        [self setupQueues];
        // 初始化网络监控
        [self setupNetworkMonitoring];
        // 初始化池配置
        [self setupSessionPool];
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
}

#pragma mark - Private Method
- (void)setupQueues {
    // 串行队列,只处理会话
    _sessionQueue = dispatch_queue_create("com.networkCoordinator.tjp.sessionQueue", DISPATCH_QUEUE_SERIAL);
    // 专用数据解析队列 并发高优先级
    _parseQueue = dispatch_queue_create("com.networkCoordinator.tjp.parseQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_set_target_queue(_parseQueue, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    // 串行监控队列
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

- (void)setupSessionPool {
    // 配置会话池
    TJPSessionPoolConfig poolConfig = {
        .maxPoolSize = 3,        // 每种类型最多3个会话
        .maxIdleTime = 180,      // 3分钟空闲超时
        .cleanupInterval = 30,   // 30秒清理一次
        .maxReuseCount = 30      // 最多复用30次
    };
    
    [self.sessionPool startWithConfig:poolConfig];
    
    // 预热常用类型的会话池
    TJPNetworkConfig *chatConfig = [self defaultConfigForSessionType:TJPSessionTypeChat];
    [self.sessionPool warmupPoolForType:TJPSessionTypeChat count:2 withConfig:chatConfig];
    
    TJPLOG_INFO(@"会话池初始化完成");
}

- (void)handleNetworkStateChange:(Reachability *)reachability {
    NetworkStatus status = [reachability currentReachabilityStatus];
    
    dispatch_async(self.monitorQueue, ^{
        // 检查是否在防抖动时间内
        NSDate *now = [NSDate date];
        if (self.lastNetworkChangeTime &&
            [now timeIntervalSinceDate:self.lastNetworkChangeTime] < self.networkChangeDebounceInterval) {
            TJPLOG_INFO(@"网络状态频繁变化，忽略当前变化");
            return;
        }
        
        // 更新最后变化时间
        self.lastNetworkChangeTime = now;
        
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
    return [self createSessionWithConfiguration:config type:TJPSessionTypeDefault];
}

- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config type:(TJPSessionType)type {
    if (!config) {
        TJPLOG_ERROR(@"[NetworkCoordinator] 配置参数为空");
        return nil;
    }
    _currConfig = config;
    
    __block id<TJPSessionProtocol> session = nil;
    // 不再直接创建session 而是从池中获取
    session = [self.sessionPool acquireSessionForType:type withConfig:config];
    
    // 验证获取到的会话是否有效
    if (!session) {
        TJPLOG_ERROR(@"[NetworkCoordinator] 从会话池获取会话失败，类型: %lu", (unsigned long)type);
        return nil;
    }
    
    
    
    // 设置会话属性
    if ([session isKindOfClass:[TJPConcreteSession class]]) {
        TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
        
        // 先设置基本属性，确保会话稳定
        concreteSession.sessionType = type;
        // 验证会话内部状态
        if (!concreteSession.sessionId || concreteSession.sessionId.length == 0) {
            TJPLOG_ERROR(@"[NetworkCoordinator] 会话sessionId无效，无法继续");
            return nil;
        }
        
        concreteSession.delegate = self;
        
        // 验证代理设置成功
        if (concreteSession.delegate != self) {
            TJPLOG_WARN(@"[NetworkCoordinator] 会话代理设置失败: %@", concreteSession.sessionId);
        } else {
            TJPLOG_INFO(@"[NetworkCoordinator] 会话代理设置成功: %@", concreteSession.sessionId);
        }
    }
    
    // 同步队列避免静态条件
    dispatch_sync(self->_sessionQueue, ^{
        // 再次验证 sessionId（防止在异步操作中被修改）
        if (!session.sessionId || session.sessionId.length == 0) {
            TJPLOG_ERROR(@"[NetworkCoordinator] 会话ID在队列操作中变为无效");
            return;
        }
        
        // 检查是否已存在相同 sessionId 的会话
        id<TJPSessionProtocol> existingSession = [self.sessionMap objectForKey:session.sessionId];
        if (existingSession) {
            TJPLOG_WARN(@"[NetworkCoordinator] 发现重复sessionId: %@，移除旧会话", session.sessionId);
            [self.sessionMap removeObjectForKey:session.sessionId];
        }
        
        // 加入活跃会话表
        [self.sessionMap setObject:session forKey:session.sessionId];
        
        // 记录会话类型映射
        NSString *previousSessionId = self.sessionTypeMap[@(type)];
        if (previousSessionId) {
            TJPLOG_INFO(@"[NetworkCoordinator] 类型 %lu 的会话映射从 %@ 更新为 %@", (unsigned long)type, previousSessionId, session.sessionId);
        }
        
        // 记录会话类型映射
        self.sessionTypeMap[@(type)] = session.sessionId;
        
        
        TJPLOG_INFO(@"[NetworkCoordinator] 成功从池中获得会话: %@, 总活跃数 : %lu", session.sessionId, (unsigned long)self.sessionMap.count);
    });
    return session;
}

// 根据类型获取会话
- (id<TJPSessionProtocol>)sessionForType:(TJPSessionType)type {
    __block id<TJPSessionProtocol> session = nil;
    dispatch_sync(self->_sessionQueue, ^{
        NSString *sessionId = self.sessionTypeMap[@(type)];
        if (sessionId) {
            session = [self.sessionMap objectForKey:sessionId];
        }
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
    // 移除逻辑修改 不再直接销毁 而是放入池中
    dispatch_barrier_async(self->_sessionQueue, ^{
        // 先从活跃会话表中移除
        [self.sessionMap removeObjectForKey:session.sessionId];
        
        // 从类型映射表中移除
        TJPSessionType sessionType = TJPSessionTypeDefault;
        if ([session isKindOfClass:[TJPConcreteSession class]]) {
            sessionType = ((TJPConcreteSession *)session).sessionType;
        }
        
        NSString *currentSessionId = self.sessionTypeMap[@(sessionType)];
        if ([currentSessionId isEqualToString:session.sessionId]) {
            [self.sessionTypeMap removeObjectForKey:@(sessionType)];
        }

        
        TJPLOG_INFO(@"移除活跃会话: %@, 剩下数量: %lu",  session.sessionId, (unsigned long)self.sessionMap.count);
        
        // 新增归还到会话池逻辑
        [self.sessionPool releaseSession:session];
    });
}

// 新增：强制移除会话（不放入池中）
- (void)forceRemoveSession:(id<TJPSessionProtocol>)session {
    dispatch_barrier_async(self->_sessionQueue, ^{
        // 从活跃会话表移除
        [self.sessionMap removeObjectForKey:session.sessionId];
        
        // 从类型映射移除
        TJPSessionType sessionType = TJPSessionTypeDefault;
        if ([session isKindOfClass:[TJPConcreteSession class]]) {
            sessionType = ((TJPConcreteSession *)session).sessionType;
        }
        
        NSString *currentSessionId = self.sessionTypeMap[@(sessionType)];
        if ([currentSessionId isEqualToString:session.sessionId]) {
            [self.sessionTypeMap removeObjectForKey:@(sessionType)];
        }
        
        // 强制从池中移除（不复用）
        [self.sessionPool removeSession:session];
        
        TJPLOG_INFO(@"强制移除会话: %@", session.sessionId);
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

- (TJPNetworkConfig *)defaultConfigForSessionType:(TJPSessionType)type {
    TJPNetworkConfig *config = [TJPNetworkConfig new];
    
    switch (type) {
        case TJPSessionTypeChat:
            // 聊天会话配置 - 重视低延迟
            config.maxRetry = 5;
            config.heartbeat = 15.0;
            config.connectTimeout = 10.0;
            break;
            
        case TJPSessionTypeMedia:
            // 媒体会话配置 - 重视吞吐量
            config.maxRetry = 3;
            config.heartbeat = 30.0;
            config.connectTimeout = 20.0;
            // 媒体会话可能需要更大的缓冲区
//            config.readBufferSize = 65536;
            break;
            
        case TJPSessionTypeSignaling:
            // 信令会话配置 - 极致低延迟
            config.maxRetry = 8;
            config.heartbeat = 5.0;
            config.connectTimeout = 5.0;
            break;
            
        default:
            // 默认配置
            config.maxRetry = 5;
            config.heartbeat = 15.0;
            config.connectTimeout = 15.0;
            break;
    }
    
    return config;
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


#pragma mark - Manage Pool Method
/**
 * 获取池中会话数量（新增）
 */
- (NSUInteger)getPooledSessionCount {
    TJPSessionPoolStats stats = [self.sessionPool getPoolStats];
    return stats.pooledSessions;
}

/**
 * 获取总会话数量（活跃 + 池中）
 */
- (NSUInteger)getTotalSessionCount {
    NSUInteger activeCount = [self sessionCount];
    NSUInteger pooledCount = [self getPooledSessionCount];
    return activeCount + pooledCount;
}

/**
 * 预热会话池
 */
- (void)warmupSessionPoolForType:(TJPSessionType)type count:(NSUInteger)count {
    TJPNetworkConfig *config = [self defaultConfigForSessionType:type];
    [self.sessionPool warmupPoolForType:type count:count withConfig:config];
}

/**
 * 获取会话池统计
 */
- (TJPSessionPoolStats)getSessionPoolStats {
    return [self.sessionPool getPoolStats];
}

/**
 * 调试：打印完整状态
 */
- (void)logCompleteStatus {
    [self logSessionPoolStatus];
    
    NSArray *activeSessions = [self safeGetAllSessions];
    TJPLOG_INFO(@"=== 活跃会话状态 ===");
    for (id<TJPSessionProtocol> session in activeSessions) {
        if ([session isKindOfClass:[TJPConcreteSession class]]) {
            TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
            TJPLOG_INFO(@"会话: %@, 类型: %lu, 状态: %@",
                       session.sessionId,
                       (unsigned long)concreteSession.sessionType,
                       session.connectState);
        }
    }
    TJPLOG_INFO(@"==================");
}

- (void)logSessionPoolStatus {
    [self.sessionPool logPoolStatus];
}

@end

