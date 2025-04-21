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



@interface TJPNetworkCoordinator () <TJPSessionDelegate>

@property (nonatomic, strong) TJPNetworkConfig *currConfig;

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
    //串行队列,只处理session
    _sessionQueue = dispatch_queue_create("com.networkCoordinator.tjp.sessionQueue", DISPATCH_QUEUE_SERIAL);
    //串行解析数据队列 专用数据解析
    _parseQueue = dispatch_queue_create("com.networkCoordinator.tjp.parseQueue", DISPATCH_QUEUE_SERIAL);
    //串行监控队列
    _monitorQueue = dispatch_queue_create("com.networkCoordinator.tjp.monitorQueue", DISPATCH_QUEUE_SERIAL);
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
    
    // 根据网络状态更新所有会话
    switch (status) {
        case NotReachable:
            // 网络不可达时强制断开所有连接
            TJPLOG_INFO(@"网络不可达，断开所有会话连接");
            [self updateAllSessionsState:TJPConnectStateDisconnecting];
            [self updateAllSessionsState:TJPConnectStateDisconnected];
            break;
            
        case ReachableViaWiFi:
        case ReachableViaWWAN:
            // 网络恢复时自动重连处于断开状态的会话
            TJPLOG_INFO(@"网络恢复，尝试自动重连");
            [self triggerAutoReconnect];
            break;
    }
}

- (void)triggerAutoReconnect {
    dispatch_async(self.monitorQueue, ^{
        NSArray *sessions = [self safeGetAllSessions];
        
        [sessions enumerateObjectsWithOptions:NSEnumerationConcurrent
                                   usingBlock:^(id<TJPSessionProtocol> session, NSUInteger idx, BOOL *stop) {
            [session triggerAutoReconnectIfNeeded];
        }];
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

