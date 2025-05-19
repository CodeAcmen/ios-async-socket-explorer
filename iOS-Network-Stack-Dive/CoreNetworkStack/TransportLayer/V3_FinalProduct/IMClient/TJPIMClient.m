//
//  TJPIMClient.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPIMClient.h"
#import "TJPNetworkCoordinator.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkConfig.h"
#import "TJPNetworkDefine.h"


@interface TJPIMClient ()

// 单一会话移除
//@property (nonatomic, strong) TJPConcreteSession *session;


// 添加通道字典
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<TJPSessionProtocol>> *channels;


@end

@implementation TJPIMClient
+ (instancetype)shared {
    static TJPIMClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _channels = [NSMutableDictionary dictionary];
    }
    return self;
}

//连接指定类型会话
- (void)connectToHost:(NSString *)host port:(uint16_t)port forType:(TJPSessionType)type {
    TJPNetworkConfig *confit = [TJPNetworkConfig configWithHost:host port:port maxRetry:5 heartbeat:15.0];
    
    // 获取会话
    id<TJPSessionProtocol> session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:confit type:type];
    
    // 保存到通道字典
    self.channels[@(type)] = session;
    
    [session connectToHost:host port:port];
}

// 兼容原有方法（使用默认会话类型）
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    [self connectToHost:host port:port forType:TJPSessionTypeDefault];
}

// 通过指定通道的session发送消息
- (void)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    
    if (!session) {
        TJPLOG_INFO(@"未找到类型为 %lu 的会话通道", (unsigned long)type);
        return;
    }
    
    NSData *tlvData = [message tlvData];
    [session sendData:tlvData];
}


// 兼容原有方法（使用默认会话类型）
- (void)sendMessage:(id<TJPMessageProtocol>)message {
    [self sendMessage:message throughType:TJPSessionTypeDefault];
}

- (void)disconnectSessionType:(TJPSessionType)type {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    if (session) {
        [session disconnectWithReason:TJPDisconnectReasonUserInitiated];
        [self.channels removeObjectForKey:@(type)];
    }

}

// 兼容原有方法（断开默认会话）
- (void)disconnect {
    [self disconnectSessionType:TJPSessionTypeDefault];
}

- (void)disconnectAll {
    for (NSNumber *key in [self.channels allKeys]) {
        id<TJPSessionProtocol> session = self.channels[key];
        [session disconnectWithReason:TJPDisconnectReasonUserInitiated];
    }
    [self.channels removeAllObjects];
}


@end
