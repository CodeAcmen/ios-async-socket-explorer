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
// 消息类型到会话类型的映射
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *contentTypeToSessionType;


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
        _contentTypeToSessionType = [NSMutableDictionary dictionary];

        // 设置默认映射
        [self setupDefaultRouting];
    }
    return self;
}


#pragma mark - Public Method
//连接指定类型会话
- (void)connectToHost:(NSString *)host port:(uint16_t)port forType:(TJPSessionType)type {
    TJPNetworkConfig *config = [[TJPNetworkCoordinator shared] defaultConfigForSessionType:type];
    
    // 设置主机和端口
    config.host = host;
    config.port = port;

    // 获取会话
    id<TJPSessionProtocol> session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:config type:type];
    
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

// 自动路由版本的发送方法
- (void)sendMessageWithAutoRoute:(id<TJPMessageProtocol>)message {
    // 获取消息内容类型
    TJPContentType contentType = message.contentType;
    
    // 查找会话类型
    NSNumber *sessionTypeNum = self.contentTypeToSessionType[@(contentType)];
    TJPSessionType sessionType = sessionTypeNum ? [sessionTypeNum unsignedIntegerValue] : TJPSessionTypeDefault;
    
    // 调用发送方法
    [self sendMessage:message throughType:sessionType];
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


#pragma mark - Private Method
- (void)setupDefaultRouting {
    //文本消息走聊天会话  媒体消息走媒体会话 因为对资源性要求不一样
    self.contentTypeToSessionType[@(TJPContentTypeText)] = @(TJPSessionTypeChat);
    self.contentTypeToSessionType[@(TJPContentTypeImage)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeAudio)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeVideo)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeFile)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeLocation)] = @(TJPSessionTypeChat);
    self.contentTypeToSessionType[@(TJPContentTypeCustom)] = @(TJPSessionTypeDefault);
    
    //  添加新的内容类型时，需更新映射表
}

// 配置路由方法
- (void)configureRouting:(TJPContentType)contentType toSessionType:(TJPSessionType)sessionType {
    self.contentTypeToSessionType[@(contentType)] = @(sessionType);
}



@end
