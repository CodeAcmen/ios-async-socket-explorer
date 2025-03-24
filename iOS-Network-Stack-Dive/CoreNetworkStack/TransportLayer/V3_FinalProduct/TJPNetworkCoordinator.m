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
#import "JZNetworkDefine.h"




@interface TJPNetworkCoordinator () <TJPSessionDelegate>
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
        _sessionMap = [NSMapTable strongToWeakObjectsMapTable];
        [self setupQueues];
        [self setupNetworkMonitoring];

    }
    return self;
}

#pragma mark - Private Method
- (void)setupQueues {
    //并发IO队列:处理所有socket读写
    self.ioQueue = dispatch_queue_create("com.networkCoordinator.tjp.ioQueue", DISPATCH_QUEUE_CONCURRENT);
    //串行解析数据队列 专用数据解析
    self.parseQueue = dispatch_queue_create("com.networkCoordinator.tjp.parseQueue", DISPATCH_QUEUE_SERIAL);

}

- (void)setupNetworkMonitoring {
    
}



#pragma mark - Public Method
- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config {
    TJPConcreteSession *session = [[TJPConcreteSession alloc] initWithConfiguration:config];
    session.delegate = self;
    dispatch_barrier_async(self->_ioQueue, ^{
        [self.sessionMap setObject:session forKey:session.sessionId];
    });
    return session;
}


- (void)updateAllSessionsStste:(TJPConnecationState)state {
}

#pragma mark - TJPSessionDelegate
/// 接收到消息
- (void)session:(id<TJPSessionProtocol>)session didReceiveData:(NSData *)data {
    //分发处理
    [[NSNotificationCenter defaultCenter] postNotificationName:kSessionDataReceiveNotification object:@{@"session": session, @"data": data}];
}
/// 状态改变
- (void)session:(id<TJPSessionProtocol>)session stateChanged:(TJPConnecationState)state {
    if (state == TJPConnecationStateDisconnected) {
        dispatch_barrier_async(self->_ioQueue, ^{
            [self.sessionMap removeObjectForKey:session.sessionId];
        });
    }
}


@end
