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
#import "TJPErrorUtil.h"


@interface TJPIMClient ()

// 通道管理
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<TJPSessionProtocol>> *channels;
// 消息类型到会话类型的映射
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *contentTypeToSessionType;
// 连接状态跟踪
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPConnectState> *connectionStates;

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
        _connectionStates = [NSMutableDictionary dictionary];

        // 设置默认映射
        [self setupDefaultRouting];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionReacquisition:) name:kSessionNeedsReacquisitionNotification object:nil];

    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Public Method
//连接指定类型会话
- (void)connectToHost:(NSString *)host port:(uint16_t)port forType:(TJPSessionType)type {
    if (host.length == 0) {
        TJPLOG_ERROR(@"[TJPIMClient] 主机地址不能为空");
        return;
    }
    
    // 检查是否已有该类型的连接
    id<TJPSessionProtocol> existingSession = self.channels[@(type)];
    if (existingSession) {
        TJPConnectState currentState = [self getConnectionStateForType:type];
        if (currentState == TJPConnectStateConnected || currentState == TJPConnectStateConnecting) {
            TJPLOG_INFO(@"[TJPIMClient] 类型 %lu 已有活跃连接，跳过重复连接", (unsigned long)type);
            return;
        }
    }
    
    // 获取配置
    TJPNetworkConfig *config = [[TJPNetworkCoordinator shared] defaultConfigForSessionType:type];
    // 设置主机和端口
    config.host = host;
    config.port = port;

    // 获取会话 优先从池中获取
    id<TJPSessionProtocol> session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:config type:type];
    
    if (!session) {
        TJPLOG_ERROR(@"[TJPIMClient] 获取会话失败，类型: %lu", (unsigned long)type);
        return;
    }
    
    // 保存到通道
    self.channels[@(type)] = session;
    self.connectionStates[@(type)] = TJPConnectStateConnecting;
    
    TJPLOG_INFO(@"[TJPIMClient] 获取会话成功: %@，开始设置KVO", session.sessionId ?: @"nil");

    // 监听会话状态变化
    [self observeSessionStateChanges:session forType:type];

    
    [session connectToHost:host port:port];
    TJPLOG_INFO(@"[TJPIMClient] 开始连接类型 %lu 的会话，目标: %@:%u", (unsigned long)type, host, port);
}

// 兼容原有方法（使用默认会话类型）
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    [self connectToHost:host port:port forType:TJPSessionTypeDefault];
}

- (void)disconnectSessionType:(TJPSessionType)type {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    if (session) {
        TJPLOG_INFO(@"[TJPIMClient] 断开类型 %lu 的会话连接", (unsigned long)type);
        [session disconnectWithReason:TJPDisconnectReasonUserInitiated];
        [self cleanupSessionForType:type];
    } else {
        TJPLOG_INFO(@"[TJPIMClient] 类型 %lu 的会话不存在，无需断开", (unsigned long)type);
    }
}

- (void)disconnectAll {
    NSArray *allTypes = [self.channels.allKeys copy];
    TJPLOG_INFO(@"[TJPIMClient] 断开所有会话连接，共 %lu 个", (unsigned long)allTypes.count);
    
    for (NSNumber *key in allTypes) {
        TJPSessionType type = [key unsignedIntegerValue];
        [self disconnectSessionType:type];
    }
}

- (void)disconnect {
    [self disconnectSessionType:TJPSessionTypeDefault];
}



// 通过指定通道的session发送消息
- (void)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type {
    [self sendMessage:message throughType:type completion:^(NSString * _Nonnull messageId, NSError * _Nonnull error) {
        if (error) {
            TJPLOG_ERROR(@"[TJPIMClient] 消息发送失败: %@", error);
        } else {
            TJPLOG_INFO(@"[TJPIMClient] 消息已发送: %@", messageId);
        }
    }];
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
    
    TJPLOG_INFO(@"[TJPIMClient] 自动路由消息，内容类型: %lu -> 会话类型: %lu", (unsigned long)contentType, (unsigned long)sessionType);
    
    // 调用发送方法
    [self sendMessage:message throughType:sessionType];
}

- (NSString *)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type completion:(nonnull void (^)(NSString *msgId, NSError *error))completion {
    return [self sendMessage:message throughType:type encryptType:TJPEncryptTypeCRC32 compressType:TJPCompressTypeZlib completion:completion];
}

- (NSString *)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType completion:(void (^)(NSString * msgId, NSError *error))completion {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    
    if (!session) {
        TJPLOG_INFO(@"[TJPIMClient] 未找到类型为 %lu 的会话通道", (unsigned long)type);
        NSError *error = [TJPErrorUtil errorWithCode:TJPErrorConnectionLost description:@"未找到会话通道" userInfo:@{}];
        if (completion) completion(@"", error);
        return nil;
    }
    
    // 检查连接状态
    TJPConnectState currentState = [self getConnectionStateForType:type];
    if (currentState != TJPConnectStateConnected) {
        TJPLOG_INFO(@"[TJPIMClient] 当前状态发送消息失败,当前状态为: %@", currentState);
        return nil;
    }
    
    NSData *tlvData = [message tlvData];
    if (!tlvData) {
        TJPLOG_ERROR(@"[TJPIMClient] 消息序列化失败，无法发送");
        return nil;
    }
    NSString *messageId = [session sendData:tlvData messageType:message.messageType encryptType:encryptType compressType:compressType completion:completion];
    
    TJPLOG_INFO(@"[TJPIMClient] 通过类型 %lu 的会话发送消息成功，大小: %lu 字节", (unsigned long)type, (unsigned long)tlvData.length);
    return messageId;
}


#pragma mark - State Management

- (BOOL)isConnectedForType:(TJPSessionType)type {
    TJPConnectState state = [self getConnectionStateForType:type];
    return [self isStateConnected:state];
}

- (TJPConnectState)getConnectionStateForType:(TJPSessionType)type {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    if (!session) {
        return TJPConnectStateDisconnected;
    }
    
    // 直接从session获取最新状态
    return session.connectState;
}

// 获取所有连接状态
- (NSDictionary<NSNumber *, TJPConnectState> *)getAllConnectionStates {
    NSMutableDictionary *states = [NSMutableDictionary dictionary];
    
    for (NSNumber *typeKey in self.channels.allKeys) {
        TJPSessionType type = [typeKey unsignedIntegerValue];
        TJPConnectState state = [self getConnectionStateForType:type];
        states[typeKey] = state;
    }
    
    return [states copy];
}

#pragma mark - State Helper Methods
- (BOOL)isStateConnected:(TJPConnectState)state {
    return [state isEqualToString:TJPConnectStateConnected];
}

- (BOOL)isStateConnecting:(TJPConnectState)state {
    return [state isEqualToString:TJPConnectStateConnecting];
}

- (BOOL)isStateDisconnected:(TJPConnectState)state {
    return [state isEqualToString:TJPConnectStateDisconnected];
}

- (BOOL)isStateDisconnecting:(TJPConnectState)state {
    return [state isEqualToString:TJPConnectStateDisconnecting];
}

- (BOOL)isStateConnectedOrConnecting:(TJPConnectState)state {
    return [self isStateConnected:state] || [self isStateConnecting:state];
}

- (BOOL)isStateDisconnectedOrDisconnecting:(TJPConnectState)state {
    return [self isStateDisconnected:state] || [self isStateDisconnecting:state];
}

#pragma mark - KVO and State Change Handling

- (void)observeSessionStateChanges:(id<TJPSessionProtocol>)session forType:(TJPSessionType)type {
    if (!session) {
        TJPLOG_ERROR(@"[TJPIMClient] observeSessionStateChanges 收到 nil session");
        return;
    }
    
    // 确保session是TJPConcreteSession类型（支持KVO）
    if (![session isKindOfClass:[TJPConcreteSession class]]) {
        TJPLOG_ERROR(@"[TJPIMClient] Session 类型不支持KVO: %@", [session class]);
        return;
    }
    TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
    
    // 验证会话状态
    if (!concreteSession.sessionId || concreteSession.sessionId.length == 0) {
        TJPLOG_ERROR(@"[TJPIMClient] 会话sessionId无效，无法设置KVO");
        return;
    }

    @try {
        // 添加KVO监听
        [concreteSession addObserver:self forKeyPath:@"connectState" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(__bridge void *)(@(type))];
        TJPLOG_INFO(@"[TJPIMClient] KVO设置成功，会话: %@", concreteSession.sessionId);
        
    } @catch (NSException *exception) {
        TJPLOG_ERROR(@"[TJPIMClient] KVO设置异常: %@，会话: %@", exception.reason, concreteSession.sessionId ?: @"nil");
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"connectState"] && [object conformsToProtocol:@protocol(TJPSessionProtocol)]) {
        TJPSessionType type = [(__bridge NSNumber *)context unsignedIntegerValue];
        
        // 正确获取新状态（字符串类型）
        TJPConnectState newState = change[NSKeyValueChangeNewKey];
        TJPConnectState oldState = change[NSKeyValueChangeOldKey];
        
        // 验证状态值
        if (!newState || ![newState isKindOfClass:[NSString class]]) {
            TJPLOG_ERROR(@"收到无效的状态变化，类型: %lu", (unsigned long)type);
            return;
        }
        
        TJPLOG_INFO(@"收到KVO状态变化，类型: %lu，%@ -> %@", (unsigned long)type, oldState ?: @"nil", newState);
        
        [self handleSessionStateChange:newState forType:type session:object];
    }
}

- (void)handleSessionStateChange:(TJPConnectState)newState
                         forType:(TJPSessionType)type
                         session:(id<TJPSessionProtocol>)session {
    
    // 更新本地状态缓存
    self.connectionStates[@(type)] = newState;
    
    TJPLOG_INFO(@"类型 %lu 的会话状态变化: %@", (unsigned long)type, newState);
    
    // 根据新状态执行相应操作
    if ([self isStateConnected:newState]) {
        TJPLOG_INFO(@"类型 %lu 的会话连接成功", (unsigned long)type);
        [self handleSessionConnected:session type:type];
        
    } else if ([self isStateDisconnected:newState]) {
        TJPLOG_INFO(@"类型 %lu 的会话已断开", (unsigned long)type);
        [self handleSessionDisconnected:session type:type];
        
    } else if ([self isStateConnecting:newState]) {
        TJPLOG_INFO(@"类型 %lu 的会话正在连接", (unsigned long)type);
        [self handleSessionConnecting:session type:type];
        
    } else if ([self isStateDisconnecting:newState]) {
        TJPLOG_INFO(@"类型 %lu 的会话正在断开", (unsigned long)type);
        [self handleSessionDisconnecting:session type:type];
    }
}

#pragma mark - Session State Handlers

- (void)handleSessionConnected:(id<TJPSessionProtocol>)session type:(TJPSessionType)type {
    // 连接成功后的处理逻辑
    // 可以在这里通知其他组件或执行初始化操作
}

- (void)handleSessionDisconnected:(id<TJPSessionProtocol>)session type:(TJPSessionType)type {
    // 连接断开后的处理逻辑
    // 根据断开原因决定是否需要重连
}

- (void)handleSessionConnecting:(id<TJPSessionProtocol>)session type:(TJPSessionType)type {
    // 连接中状态的处理逻辑
}

- (void)handleSessionDisconnecting:(id<TJPSessionProtocol>)session type:(TJPSessionType)type {
    // 断开中状态的处理逻辑
}

#pragma mark - Cleanup and Configuration

- (void)cleanupSessionForType:(TJPSessionType)type {
    id<TJPSessionProtocol> session = self.channels[@(type)];
    if (session) {
        // 移除KVO观察
        if ([session isKindOfClass:[TJPConcreteSession class]]) {
            TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
            @try {
                [concreteSession removeObserver:self forKeyPath:@"connectState"];
                TJPLOG_INFO(@"移除类型 %lu 会话的KVO监听", (unsigned long)type);
            } @catch (NSException *exception) {
                TJPLOG_WARN(@"移除KVO观察时发生异常: %@", exception.reason);
            }
        }
        
        // 从通道中移除
        [self.channels removeObjectForKey:@(type)];
        [self.connectionStates removeObjectForKey:@(type)];
        
        TJPLOG_INFO(@"清理类型 %lu 的会话: %@", (unsigned long)type, session.sessionId);
    }
}

- (void)configureRouting:(TJPContentType)contentType toSessionType:(TJPSessionType)sessionType {
    self.contentTypeToSessionType[@(contentType)] = @(sessionType);
    TJPLOG_INFO(@"配置路由: 内容类型 %lu -> 会话类型 %lu", (unsigned long)contentType, (unsigned long)sessionType);
}

- (void)handleSessionReacquisition:(NSNotification *)notification {
    TJPSessionType sessionType = [notification.userInfo[@"sessionType"] unsignedIntegerValue];
    
    TJPLOG_INFO(@"收到会话重新获取通知，类型: %lu", (unsigned long)sessionType);
    
    // 清理旧会话
    [self cleanupSessionForType:sessionType];
}

- (void)setupDefaultRouting {
    // 文本消息走聊天会话，媒体消息走媒体会话，因为对资源性要求不一样
    self.contentTypeToSessionType[@(TJPContentTypeText)] = @(TJPSessionTypeChat);
    self.contentTypeToSessionType[@(TJPContentTypeImage)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeAudio)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeVideo)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeFile)] = @(TJPSessionTypeMedia);
    self.contentTypeToSessionType[@(TJPContentTypeLocation)] = @(TJPSessionTypeChat);
    self.contentTypeToSessionType[@(TJPContentTypeCustom)] = @(TJPSessionTypeDefault);
    
    TJPLOG_INFO(@"默认路由配置完成");
    // 添加新的内容类型时，需更新映射表
}




@end
