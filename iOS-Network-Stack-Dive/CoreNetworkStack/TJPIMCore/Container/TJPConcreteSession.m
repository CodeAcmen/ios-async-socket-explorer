//
//  TJPConcreteSession.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPConcreteSession.h"
#import <GCDAsyncSocket.h>
#import <Reachability/Reachability.h>

#import "TJPNetworkConfig.h"
#import "TJPNetworkDefine.h"

#import "TJPErrorUtil.h"
#import "TJPNetworkCoordinator.h"
#import "TJPReconnectPolicy.h"
#import "TJPDynamicHeartbeat.h"
#import "TJPMessageParser.h"
#import "TJPMessageBuilder.h"
#import "TJPMessageContext.h"
#import "TJPParsedPacket.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkUtil.h"
#import "TJPConnectStateMachine.h"
#import "TJPNetworkCondition.h"
#import "TJPMetricsConsoleReporter.h"
#import "TJPConnectionDelegate.h"
#import "TJPConnectionManager.h"



static const NSTimeInterval kDefaultRetryInterval = 10;

@interface TJPConcreteSession () <TJPConnectionDelegate, TJPReconnectPolicyDelegate>

@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

@property (nonatomic, strong) TJPConnectionManager *connectionManager;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

//消息超时重传定时器
@property (nonatomic, strong) NSMutableDictionary<NSString *, dispatch_source_t> *retransmissionTimers;

/// 动态心跳
@property (nonatomic, strong) TJPDynamicHeartbeat *heartbeatManager;
/// 序列号管理
@property (nonatomic, strong) TJPSequenceManager *seqManager;

/// 协议处理
@property (nonatomic, strong) TJPMessageParser *parser;


/*    版本协商规则    */
//上次握手时间
@property (nonatomic, strong) NSDate *lastHandshakeTime;
//断开连接事件
@property (nonatomic, strong) NSDate *disconnectionTime;
//是否完成握手
@property (nonatomic, assign) BOOL hasCompletedHandshake;

//协商后的版本号
@property (nonatomic, assign) uint16_t negotiatedVersion;

//协商后的特性标志
@property (nonatomic, assign) uint16_t negotiatedFeatures;



@end

@implementation TJPConcreteSession

- (void)dealloc {
    TJPLogDealloc();
    //清理定时器
    [self cancelAllRetransmissionTimersSync];
    [self prepareForRelease];

}

#pragma mark - Lifecycle
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config {
    if (self = [super init]) {
        _config = config;
        _autoReconnectEnabled = YES;
        _sessionId = [[NSUUID UUID] UUIDString];
        _retransmissionTimers = [NSMutableDictionary dictionary];
        _pendingMessages = [NSMutableDictionary dictionary];

        // 创建专用队列（串行，中等优先级）
        _sessionQueue = dispatch_queue_create("com.concreteSession.tjp.sessionQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_sessionQueue, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        
        
        // 初始化状态机（初始状态：断开连接）
        _stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected setupStandardRules:YES];
        [self setupStateMachine];
        
        // 初始化连接管理器
        _connectionManager = [[TJPConnectionManager alloc] initWithDelegateQueue:_sessionQueue];
        _connectionManager.delegate = self;
        _connectionManager.connectionTimeout = 30.0;
        _connectionManager.useTLS = config.useTLS;


        // 初始化组件
        [self setupComponentWithConfig:config];
        
                
        // 注册心跳超时通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHeartbeatTimeout:)
                                                     name:kHeartbeatTimeoutNotification
                                                   object:nil];
            
    }
    return self;
}

- (void)setupComponentWithConfig:(TJPNetworkConfig *)config {
    // 序列号管理
    _seqManager = [[TJPSequenceManager alloc] init];
    
    // 初始化协议解析器
    _parser = [[TJPMessageParser alloc] initWithBufferStrategy:TJPBufferStrategyAuto];
    
    // 初始化重连策略
    _reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:config.maxRetry baseDelay:config.baseDelay qos:TJPNetworkQoSDefault delegate:self];
    
    // 初始化心跳管理
    _heartbeatManager = [[TJPDynamicHeartbeat alloc] initWithBaseInterval:config.heartbeat seqManager:_seqManager session:self];
    
    // 自定义前台模式参数
    [_heartbeatManager configureWithBaseInterval:30.0 minInterval:15.0 maxInterval:300.0 forMode:TJPHeartbeatModeForeground];
                                      
    // 自定义后台模式参数
    [_heartbeatManager configureWithBaseInterval:90.0 minInterval:45.0 maxInterval:600.0 forMode:TJPHeartbeatModeBackground];
}

//制定转换规则
- (void)setupStateMachine {
    __weak typeof(self) weakSelf = self;
    // 设置无效转换处理器
    [_stateMachine setInvalidTransitionHandler:^(TJPConnectState state, TJPConnectEvent event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 记录错误
        TJPLOG_ERROR(@"会话 %@ 状态转换错误: %@ -> %@，尝试恢复", strongSelf.sessionId, state, event);

        // 尝试恢复逻辑
        if ([event isEqualToString:TJPConnectEventConnect] &&
            ![state isEqualToString:TJPConnectStateDisconnected]) {
            // 如果试图从非断开状态发起连接，先强制断开
            [strongSelf.stateMachine sendEvent:TJPConnectEventForceDisconnect];
            // 延迟后再尝试连接
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [strongSelf.stateMachine sendEvent:TJPConnectEventConnect];
            });
        }
    }];
    
    // 设置状态变化监听
    [_stateMachine onStateChange:^(TJPConnectState oldState, TJPConnectState newState) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        TJPLOG_INFO(@"会话 %@ 状态变化: %@ -> %@", strongSelf.sessionId, oldState, newState);

        // 通知代理
        if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(session:didChangeState:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.delegate session:strongSelf didChangeState:newState];
            });
        }
        
        // 根据新状态执行相应操作
        if ([newState isEqualToString:TJPConnectStateConnected]) {
            // 更新心跳管理器的 session 引用 并启动心跳 updateSession中包含启动心跳方法
            [strongSelf.heartbeatManager updateSession:strongSelf];
            TJPLOG_INFO(@"连接成功，心跳已启动，当前间隔 %.1f 秒", strongSelf.heartbeatManager.currentInterval);

            [strongSelf handleConnectedState];
        } else if ([newState isEqualToString:TJPConnectStateDisconnecting]) {
            // 状态改为开始断开就更新时间
            [strongSelf handleDisconnectedState];
        } else if ([newState isEqualToString:TJPConnectStateDisconnected]) {
            // 断开连接，停止心跳
            [strongSelf handleDisconnectedState];
            
            // 特殊处理强制断开后的逻辑
            if (strongSelf.disconnectReason == TJPDisconnectReasonForceReconnect) {
                [strongSelf handleForceDisconnectComplete];
            }
            
        }
    }];
}

#pragma mark - TJPConnectionDelegate
- (void)connectionWillConnect:(TJPConnectionManager *)connection {
    // 记录日志，不需要特殊处理
    TJPLOG_INFO(@"连接即将建立");
}

- (void)connectionDidConnect:(TJPConnectionManager *)connection {
    dispatch_async(self.sessionQueue, ^{
        TJPLOG_INFO(@"连接成功，准备给状态机发送连接成功事件");
        self.isReconnecting = NO;
        
        // 触发连接成功事件 状态转换为"已连接"
        [self.stateMachine sendEvent:TJPConnectEventConnectSuccess];
        
        // 开始网络指标监控
        [TJPMetricsConsoleReporter startWithConfig:self.config];
    });
}

- (void)connectionWillDisconnect:(TJPConnectionManager *)connection reason:(TJPDisconnectReason)reason {
    dispatch_async(self.sessionQueue, ^{
        // 如果是从已连接状态断开，发送断开事件
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            [self.stateMachine sendEvent:TJPConnectEventDisconnect];
        }
    });
}

- (void)connection:(TJPConnectionManager *)connection didDisconnectWithError:(NSError *)error reason:(TJPDisconnectReason)reason {
    dispatch_async(self.sessionQueue, ^{
        self.isReconnecting = NO;
        
        // 保存断开原因，如果没有明确的原因，使用连接管理器的原因
        if (self.disconnectReason == TJPDisconnectReasonNone) {
            self.disconnectReason = reason;
        }
        
        // 如果是从连接中状态断开，发送连接失败事件
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnecting]) {
            [self.stateMachine sendEvent:TJPConnectEventConnectFailure];
        }
        // 如果是从断开中状态断开，发送断开完成事件
        else if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnecting]) {
            [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        }
        // 如果是从已连接状态异常断开，发送网络错误事件后发送断开完成事件
        else if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            [self.stateMachine sendEvent:TJPConnectEventNetworkError];
            [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        }
        
        // 清理资源
        [self cleanupAfterDisconnect];
        
        // 处理重连策略
        [self handleReconnectionAfterDisconnect];
    });
}

- (void)connection:(TJPConnectionManager *)connection didReceiveData:(NSData *)data {
    dispatch_async([TJPNetworkCoordinator shared].parseQueue, ^{
        TJPLOG_INFO(@"读取到数据，准备解析");
        
        // 使用解析器解析数据
        [self.parser feedData:data];
        
        // 解析数据
        while ([self.parser hasCompletePacket]) {
            TJPLOG_INFO(@"开始解析数据包");
            TJPParsedPacket *packet = [self.parser nextPacket];
            if (!packet) {
                TJPLOG_INFO(@"数据解析出错，TJPParsedPacket为空，请检查代码,后续流程停止");
                return;
            }
            // 处理数据包
            [self processReceivedPacket:packet];
        }
    });
}



- (void)connectionDidSecure:(TJPConnectionManager *)connection {
    TJPLOG_INFO(@"连接已建立TLS安全层");
}



#pragma mark - TJPSessionProtocol
/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self.sessionQueue, ^{
        if (host.length == 0) {
            TJPLOG_ERROR(@"主机地址不能为空,请检查!!");
            return;
        }
        self.host = host;
        self.port = port;
        
        //通过状态机检查当前状态
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
            TJPLOG_INFO(@"当前状态无法连接主机,当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        
        TJPLOG_INFO(@"session 准备给状态机发送连接事件");

        //触发连接事件 状态转换为"连接中"
        [self.stateMachine sendEvent:TJPConnectEventConnect];
        
        self.disconnectReason = TJPDisconnectReasonNone;

        // 使用连接管理器进行连接  职责拆分 session不再负责连接方法
        [self.connectionManager connectToHost:host port:port];

    });
}

/// 发送消息
- (void)sendData:(NSData *)data {
    dispatch_async(self.sessionQueue, ^{
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_INFO(@"当前状态发送消息失败,当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        
        // 参数验证
        if (!data) {
            TJPLOG_ERROR(@"发送数据为空");
            return;
        }
        
        // 检查数据大小
        if (data.length > TJPMAX_BODY_SIZE) {
            TJPLOG_ERROR(@"数据大小超过限制: %lu > %d", (unsigned long)data.length, TJPMAX_BODY_SIZE);
            return;
        }
        
        
        //创建序列号
        uint32_t seq = [self.seqManager nextSequenceForCategory:TJPMessageCategoryNormal];
        
        // 获取当前会话使用的加密和压缩类型
        TJPEncryptType encryptType = TJPEncryptTypeCRC32;
        TJPCompressType compressType = TJPCompressTypeZlib;

        
        //构造协议包  实际通过Socket发送的协议包(协议头+原始数据)
        NSData *packet = [TJPMessageBuilder buildPacketWithMessageType:TJPMessageTypeNormalData sequence:seq payload:data encryptType:encryptType compressType:compressType sessionID:self.sessionId];
        
        if (!packet) {
            TJPLOG_ERROR(@"消息包构建失败");
            return;
        }
        
        //消息的上下文,用于跟踪消息状态(发送时间,重试次数,序列号)
        TJPMessageContext *context = [TJPMessageContext contextWithData:data seq:seq messageType:TJPMessageTypeNormalData encryptType:encryptType compressType:compressType sessionId:self.sessionId];
        //存储待确认消息
        self.pendingMessages[@(context.sequence)] = context;
        
        //设置超时重传
        [self scheduleRetransmissionForSequence:context.sequence];
        
        TJPLOG_INFO(@"session 消息即将发出, 序列号: %u, 大小: %lu字节", seq, (unsigned long)packet.length);
        
        //使用连接管理器发送消息
        [self.connectionManager sendData:packet withTimeout:-1 tag:context.sequence];
    });
}

/// 发送心跳包
- (void)sendHeartbeat:(NSData *)heartbeatData {
    dispatch_async(self.sessionQueue, ^{
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_INFO(@"当前状态发送心跳包失败, 当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        TJPLOG_INFO(@"session 正在发送心跳包");
        [self.connectionManager sendData:heartbeatData withTimeout:-1 tag:0];
    });
}

- (void)disconnectWithReason:(TJPDisconnectReason)reason {
    dispatch_async(self.sessionQueue, ^{
        // 避免重复断开
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
            TJPLOG_INFO(@"当前已是断开状态，无需再次断开");
            return;
        }
        
        //存储断开原因
        self.disconnectReason = reason;
        
        // 状态转换为"断开中"
        [self.stateMachine sendEvent:TJPConnectEventDisconnect];

        
        //使用管理器断开连接
        [self.connectionManager disconnectWithReason:reason];

        //停止心跳
        [self.heartbeatManager stopMonitoring];
        
        //清理资源
        [self.pendingMessages removeAllObjects];
        [self cancelAllRetransmissionTimers];

        //停止监控
        [TJPMetricsConsoleReporter stop];
        
        //状态转换为"已断开连接"
        [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        
        // 通知协调器处理可能的重连
        if (reason == TJPDisconnectReasonNetworkError ||
            reason == TJPDisconnectReasonHeartbeatTimeout ||
            reason == TJPDisconnectReasonIdleTimeout) {
            
            if ([self.delegate respondsToSelector:@selector(sessionNeedsReconnect:)]) {
                [self.delegate sessionNeedsReconnect:self];
            }
        }

    });
}

- (void)disconnect {
   [self disconnectWithReason:TJPDisconnectReasonUserInitiated];
}

- (void)updateConnectionState:(TJPConnectState)state {
    //事件驱动状态变更
    TJPConnectEvent event = [self eventForTargetState:state];
    if (event) {
        [self.stateMachine sendEvent:event];
    }
}

- (TJPConnectState)connectState {
    return self.stateMachine.currentState;
}


- (void)forceReconnect {
    dispatch_async(self.sessionQueue, ^{
        //重连之前确保连接断开
        [self disconnectWithReason:TJPDisconnectReasonForceReconnect];

        //延迟一点时间确保连接完全断开
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), self.sessionQueue, ^{
            // 重置连接相关的状态
            [self resetConnection];
            
            // 重新连接
            [self connectToHost:self.host port:self.port];
        });
    });
}

- (void)networkDidBecomeAvailable {
   dispatch_async(self.sessionQueue, ^{
       // 检查是否已经在重连
       if (self.isReconnecting) {
           TJPLOG_INFO(@"已有重连过程在进行，忽略");
           return;
       }
       
       // 只有当前状态为断开状态且启用了自动重连才尝试重连
       if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected] &&
           self.autoReconnectEnabled &&
           self.disconnectReason != TJPDisconnectReasonUserInitiated) {
           
           self.isReconnecting = YES;
           TJPLOG_INFO(@"网络恢复，尝试自动重连");
           
           [self.reconnectPolicy attemptConnectionWithBlock:^{
               [self connectToHost:self.host port:self.port];
           }];
       }
   });
}

- (void)networkDidBecomeUnavailable {
   dispatch_async(self.sessionQueue, ^{
       // 如果当前连接中或已连接，则标记为网络错误并断开
       if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnecting] ||
           [self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
           
           [self disconnectWithReason:TJPDisconnectReasonNetworkError];
       }
   });
}

- (void)prepareForRelease {
   [self.connectionManager disconnect];
   [self.heartbeatManager stopMonitoring];
    [TJPMetricsConsoleReporter stop];
   [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)forceDisconnect {
    TJPLOG_INFO(@"强制断开连接 - 当前状态: %@", self.stateMachine.currentState);
    
    //更新断开原因
    self.disconnectReason = TJPDisconnectReasonForceReconnect;
    
    //发送强制断开事件
    [self.stateMachine sendEvent:TJPConnectEventForceDisconnect];
    
    //关闭底层连接
    [self.connectionManager forceDisconnect];
    
    //停止心跳
    [self.heartbeatManager stopMonitoring];
    
    //清理定时器和待确认消息
    [self cancelAllRetransmissionTimersSync];
    [self.pendingMessages removeAllObjects];
    
    //停止监控
    [TJPMetricsConsoleReporter stop];
    
    TJPLOG_INFO(@"强制断开完成");
}


#pragma mark - Version Handshake
- (void)performVersionHandshake {
    //协议版本握手逻辑
    uint8_t majorVersion = kProtocolVersionMajor;
    uint8_t minorVersion = kProtocolVersionMinor;
    
    //设置连接管理器的版本信息
    [self.connectionManager setVersionInfo:majorVersion minorVersion:minorVersion];
    
    //构建版本握手数据包
    TJPFinalAdavancedHeader header;
    memset(&header, 0, sizeof(TJPFinalAdavancedHeader));
    
    //转换网络字节序
    header.magic = htonl(kProtocolMagic);
    header.version_major = majorVersion;
    header.version_minor = minorVersion;
    //控制类型消息
    header.msgType = htons(TJPMessageTypeControl);
    header.timestamp = htonl((uint32_t)[[NSDate date] timeIntervalSince1970]);
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons([TJPMessageBuilder sessionIDFromUUID:self.sessionId]);
    
    // 获取序列号
    uint32_t seq = [self.seqManager nextSequenceForCategory:TJPMessageCategoryControl];
    header.sequence = htonl(seq);

#warning //构建版本协商TLV数据 - 这里使用我构建的数据  实际环境需要替换成你需要的
    NSMutableData *tlvData = [NSMutableData data];
    //版本信息标签
    uint16_t versionTag = htons(0x0001);
    //版本信息长度
    uint32_t versionLength = htonl(4);
    // 版本值(Value第一部分): 将主版本号和次版本号打包为一个16位整数
    // 主版本占用高8位，次版本占用低8位
    uint16_t versionValue = htons((majorVersion << 8) | minorVersion);
   
    // 使用定义的特性标志
    uint16_t featureFlags = htons(TJP_SUPPORTED_FEATURES);
    
    // 记录日志，便于调试
    NSLog(@"发送版本协商: 版本=%d.%d, 特性=0x%04X", majorVersion, minorVersion, TJP_SUPPORTED_FEATURES);

    [tlvData appendBytes:&versionTag length:sizeof(uint16_t)];
    [tlvData appendBytes:&versionLength length:sizeof(uint32_t)];
    [tlvData appendBytes:&versionValue length:sizeof(uint16_t)];
    [tlvData appendBytes:&featureFlags length:sizeof(uint16_t)];
    
    header.bodyLength = htonl((uint32_t)tlvData.length);

    // CRC32计算校验和
    uint32_t checksum = [TJPNetworkUtil crc32ForData:tlvData];
    header.checksum = htonl(checksum);
    

    // 构建完整的握手数据包
    NSMutableData *handshakeData = [NSMutableData dataWithBytes:&header length:sizeof(TJPFinalAdavancedHeader)];
    [handshakeData appendData:tlvData];
    
    // 创建上下文并加入待确认队列
    TJPMessageContext *context = [TJPMessageContext contextWithData:tlvData
                                                                seq:seq
                                                        messageType:TJPMessageTypeControl
                                                        encryptType:TJPEncryptTypeNone
                                                       compressType:TJPCompressTypeNone
                                                          sessionId:self.sessionId];
    // 控制消息通常不需要重传
    context.maxRetryCount = 0;
    
    // 存储待确认消息
    self.pendingMessages[@(seq)] = context;
    
    
    // 发送握手数据包
    [self.connectionManager sendData:handshakeData withTimeout:10.0 tag:header.sequence];
    
    TJPLOG_INFO(@"已发送版本握手包，等待服务器响应");
}



#pragma mark - TJPReconnectPolicyDelegate
- (void)reconnectPolicyDidReachMaxAttempts:(TJPReconnectPolicy *)reconnectPolicy {
    TJPLOG_ERROR(@"最大重连次数已达到，连接失败");
    dispatch_async(self.sessionQueue, ^{
        // 停止重连尝试
        [self.reconnectPolicy stopRetrying];
        self.isReconnecting = NO;

        // 将状态机转为断开状态
        [self.stateMachine sendEvent:TJPConnectEventConnectFailure];

        // 关闭 socket 连接
        [self.connectionManager disconnect];
        
        // 停止心跳
        [self.heartbeatManager stopMonitoring];
        
        // 停止Timer
        [self cancelAllRetransmissionTimers];

        // 清理资源
        [self.pendingMessages removeAllObjects];
            
        // 停止网络指标监控
        [TJPMetricsConsoleReporter stop];

        TJPLOG_INFO(@"当前连接退出");
    });
}

- (NSString *)getCurrentConnectionState {
    return self.stateMachine.currentState;
}

#pragma mark - Private Methods
- (void)handleConnectedState {
    // 如果有积压消息 发送积压消息
    [self flushPendingMessages];

    // 判断是否需要握手
    if ([self shouldPerformHandshake]) {
        [self performVersionHandshake];
    } else {
        TJPLOG_INFO(@"使用现有协商结果，跳过版本握手");
    }
}

- (void)handleDisconnectingState {
    self.disconnectionTime = [NSDate date];
}

- (void)handleDisconnectedState {
    [self.heartbeatManager stopMonitoring];
}

- (void)handleForceDisconnectComplete {
    TJPLOG_INFO(@"强制断开完成，会话 %@ 已就绪", self.sessionId);
    // 重置一些状态
    self.isReconnecting = NO;
    
    // 通知协调器可以进行后续操作（如重连或回收）
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidForceDisconnect:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate sessionDidForceDisconnect:self];
        });
    }
}

- (void)scheduleRetransmissionForSequence:(uint32_t)sequence {
    // 取消之前可能存在的重传计时器
    NSString *timerKey = [NSString stringWithFormat:@"retry_%u", sequence];
    dispatch_source_t existingTimer = self.retransmissionTimers[timerKey];
    if (existingTimer) {
        dispatch_source_cancel(existingTimer);
        [self.retransmissionTimers removeObjectForKey:timerKey];
    }
    
    //获取消息上下文
    TJPMessageContext *context = self.pendingMessages[@(sequence)];
    if (!context) {
        TJPLOG_ERROR(@"无法为序列号 %u 安排重传! 原因:消息上下文不存在", sequence);
        return;
    }
    
    //如果已经达到最大重试次数,不再安排重传
    if (context.retryCount >= context.maxRetryCount) {
        TJPLOG_WARN(@"消息 %u 已达到最大重试次数 %ld，不再重试", sequence, (long)context.maxRetryCount);
        return;
    }
    
    //创建GCD定时器
    __weak typeof(self) weakSelf = self;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.sessionQueue);
    
    //设置定时器间隔 (默认3秒一次)
    NSTimeInterval retryInterval = context.retryTimeout > 0 ? context.retryTimeout : kDefaultRetryInterval;
    uint64_t intervalInNanoseconds = (uint64_t)(retryInterval * NSEC_PER_SEC);
    
    
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalInNanoseconds),
                              DISPATCH_TIME_FOREVER, // 不重复
                              (1ull * NSEC_PER_SEC) / 10); // 100ms的精度
    
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf handleRetransmissionForSequence:sequence];
    });
    
    // 设置定时器取消处理函数
    dispatch_source_set_cancel_handler(timer, ^{
        TJPLOG_INFO(@"取消消息 %u 的重传计时器", sequence);
    });
    
    // 保存定时器
    self.retransmissionTimers[timerKey] = timer;
    
    // 启动定时器
    dispatch_resume(timer);
    
    TJPLOG_INFO(@"为消息 %u 安排重传，间隔 %.1f 秒，当前重试次数 %ld", sequence, retryInterval, (long)context.retryCount);
}


// 重传处理方法
- (void)handleRetransmissionForSequence:(uint32_t)sequence {
    // 获取消息上下文
    TJPMessageContext *context = self.pendingMessages[@(sequence)];
    
    // 清理计时器
    NSString *timerKey = [NSString stringWithFormat:@"retry_%u", sequence];
    dispatch_source_t timer = self.retransmissionTimers[timerKey];
    if (timer) {
        dispatch_source_cancel(timer);
        [self.retransmissionTimers removeObjectForKey:timerKey];
    }
    
    // 如果消息已确认，不需要重传
    if (!context) {
        TJPLOG_INFO(@"消息 %u 已确认，不需要重传", sequence);
        return;
    }
    
    // 检查连接状态
    if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
        TJPLOG_WARN(@"当前连接状态为 %@，无法重传消息 %u", self.stateMachine.currentState, sequence);
        return;
    }
    
    // 增加重试次数
    context.retryCount++;
    
    // 检查重试次数是否已达上限
    if (context.retryCount >= context.maxRetryCount) {
        TJPLOG_ERROR(@"消息 %u 重传失败，已达最大重试次数 %ld", sequence, (long)context.maxRetryCount);
        
        // 移除待确认消息
        [self.pendingMessages removeObjectForKey:@(sequence)];
        
        // 通知上层应用消息发送失败
        if (self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToSendMessageWithSequence:error:)]) {
            NSError *error = [TJPErrorUtil errorWithCode:TJPErrorMessageRetryExceeded
                                           description:[NSString stringWithFormat:@"消息 %u 发送失败，超过最大重试次数", sequence]
                                             userInfo:@{@"sequence": @(sequence), @"retryCount": @(context.retryCount)}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate session:self didFailToSendMessageWithSequence:sequence error:error];
            });
        }
        return;
    }
    
    // 执行重传
    TJPLOG_INFO(@"重传消息 %u，第 %ld 次尝试", sequence, (long)context.retryCount + 1);
    NSData *packet = [context buildRetryPacket];
    [self.connectionManager sendData:packet withTimeout:-1 tag:sequence];

    // 安排下一次重传
    [self scheduleRetransmissionForSequence:sequence];
}


- (void)cancelAllRetransmissionTimers {
    dispatch_async(self.sessionQueue, ^{
        [self cancelAllRetransmissionTimersSync];
    });
}

- (void)cancelAllRetransmissionTimersSync {
    if (!_retransmissionTimers) return;
    
    for (NSString *key in [_retransmissionTimers allKeys]) {
        dispatch_source_t timer = _retransmissionTimers[key];
        if (timer) {
            dispatch_source_cancel(timer);
        }
    }
    [_retransmissionTimers removeAllObjects];
    
    TJPLOG_INFO(@"已清理所有重传计时器");
}

- (void)flushPendingMessages {
   dispatch_async(self.sessionQueue, ^{
       if ([self.pendingMessages count] == 0) {
           TJPLOG_INFO(@"没有积压消息需要发送");
           return;
       }
       
       TJPLOG_INFO(@"开始发送积压消息，共 %lu 条", (unsigned long)self.pendingMessages.count);
       
       for (NSNumber *seq in [self.pendingMessages allKeys]) {
           TJPMessageContext *context = self.pendingMessages[seq];
           NSData *packet = [context buildRetryPacket];
           [self.connectionManager sendData:packet withTimeout:-1 tag:context.sequence];
           [self scheduleRetransmissionForSequence:context.sequence];
       }
   });
}

- (BOOL)shouldPerformHandshake {
    // 首次连接或未完成握手
    if (!self.hasCompletedHandshake) {
        return YES;
    }
    
    // 长时间未握手（超过24小时）
    NSTimeInterval timeSinceLastHandshake = [[NSDate date] timeIntervalSinceDate:self.lastHandshakeTime];
    if (timeSinceLastHandshake > 24 * 3600) { // 24小时
        return YES;
    }
    
    // 长时间断线后重连（超过5分钟）
    if (self.disconnectionTime) {
        NSTimeInterval disconnectionDuration = [[NSDate date] timeIntervalSinceDate:self.disconnectionTime];
        if (disconnectionDuration > 300) { // 5分钟
            return YES;
        }
    }
    
    return NO;
}



- (void)resetConnection {
//   [self.seqManager resetSequences];
//   [self.heartbeatManager reset];
}

- (void)handleReconnectionAfterDisconnect {
    // 检查是否需要自动重连
    if (!self.autoReconnectEnabled ||
        self.disconnectReason == TJPDisconnectReasonUserInitiated ||
        self.isReconnecting) {
        return;
    }
    
    // 检查网络状态，只有在网络可达时才尝试重连
    if ([[TJPNetworkCoordinator shared].reachability currentReachabilityStatus] != NotReachable &&
        (self.disconnectReason == TJPDisconnectReasonNetworkError ||
         self.disconnectReason == TJPDisconnectReasonHeartbeatTimeout ||
         self.disconnectReason == TJPDisconnectReasonIdleTimeout)) {
        
        self.isReconnecting = YES;
//        TJPLOG_INFO(@"开始重连策略，原因: %@", [self reasonToString:self.disconnectReason]);
        
        
        // 准备重连
        [self.reconnectPolicy attemptConnectionWithBlock:^{
            // 再次检查状态
            if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
                [self connectToHost:self.host port:self.port];
            }
        }];
    }
}

- (void)cleanupAfterDisconnect {
   // 停止心跳
   [self.heartbeatManager stopMonitoring];
   
   // 取消所有重传计时器
   [self cancelAllRetransmissionTimers];
   
   // 清理待确认消息
   [self.pendingMessages removeAllObjects];
   
   // 停止网络监控
   [TJPMetricsConsoleReporter stop];
}


- (void)processReceivedPacket:(TJPParsedPacket *)packet {
    TJPLOG_INFO(@"处理数据包: 类型=%hu, 序列号=%u", packet.messageType, packet.sequence);
   switch (packet.messageType) {
       case TJPMessageTypeNormalData:
           TJPLOG_INFO(@"处理普通数据包，序列号: %u", packet.sequence);
           [self handleDataPacket:packet];
           break;
       case TJPMessageTypeHeartbeat:
           TJPLOG_INFO(@"处理心跳包，序列号: %u", packet.sequence);
           [self.heartbeatManager heartbeatACKNowledgedForSequence:packet.sequence];
           break;
       case TJPMessageTypeACK:
           TJPLOG_INFO(@"处理ACK包，序列号: %u", packet.sequence);
           [self handleACKForSequence:packet.sequence];
           break;
       case TJPMessageTypeControl:
           TJPLOG_INFO(@"处理控制包，序列号: %u", packet.sequence);
           [self handleControlPacket:packet];
           break;
       default:
           TJPLOG_WARN(@"收到未知消息类型 %hu", packet.messageType);
           break;
   }
}

- (void)handleDataPacket:(TJPParsedPacket *)packet {
   if (!packet.payload) {
       TJPLOG_ERROR(@"数据包载荷为空");
       return;
   }
   
   // 向上层通知收到数据
   if (self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveRawData:)]) {
       dispatch_async(dispatch_get_main_queue(), ^{
           [self.delegate session:self didReceiveRawData:packet.payload];
       });
   }
   
   // 发送ACK确认 - 确认接收到的数据包
    [self sendAckForPacket:packet messageCategory:TJPMessageCategoryNormal];
}

- (void)handleControlPacket:(TJPParsedPacket *)packet {
   // 解析控制包数据，处理版本协商等控制消息
   TJPLOG_INFO(@"收到控制包，长度: %lu", (unsigned long)packet.payload.length);
   
    // 确保数据包长度足够
    if (packet.payload.length >= 12) { // 至少包含 Tag(2) + Length(4) + Value(2) + Flags(2)
        const void *bytes = packet.payload.bytes;
        uint16_t tag = 0;
        uint32_t length = 0;
        uint16_t value = 0;
        uint16_t flags = 0;
        
        // 提取 TLV 字段
        memcpy(&tag, bytes, sizeof(uint16_t));
        memcpy(&length, bytes + 2, sizeof(uint32_t));
        memcpy(&value, bytes + 6, sizeof(uint16_t));
        memcpy(&flags, bytes + 8, sizeof(uint16_t));
        
        // 转换网络字节序到主机字节序
        tag = ntohs(tag);
        length = ntohl(length);
        value = ntohs(value);
        flags = ntohs(flags);
        
        // 检查是否是版本协商响应
        if (tag == 0x0001) { // 版本标签
            // 提取版本信息
            uint8_t majorVersion = (value >> 8) & 0xFF;
            uint8_t minorVersion = value & 0xFF;
            
            TJPLOG_INFO(@"收到版本协商响应: 版本=%d.%d, 特性=0x%04X",
                        majorVersion, minorVersion, flags);
            
            // 保存协商结果到会话属性中
            self.negotiatedVersion = value;
            self.negotiatedFeatures = flags;
            self.lastHandshakeTime = [NSDate date];
            self.hasCompletedHandshake = YES;

            
            // 根据协商结果配置会话
            [self configureSessionWithFeatures:flags];
            
            // 通知代理版本协商完成
            if (self.delegate && [self.delegate respondsToSelector:@selector(session:didCompleteVersionNegotiation:features:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate session:self didCompleteVersionNegotiation:self.negotiatedVersion features:self.negotiatedFeatures];
                });
            }
        } else {
            TJPLOG_INFO(@"收到未知控制消息，标签: 0x%04X", tag);
        }
    } else {
        TJPLOG_WARN(@"控制包数据长度不足，无法解析");
    }
    
   // 发送ACK确认
    [self sendAckForPacket:packet messageCategory:TJPMessageCategoryControl];
}

- (void)configureSessionWithFeatures:(uint16_t)features {
    TJPLOG_INFO(@"根据协商特性配置会话: 0x%04X", features);
    
    // 检查各个特性位并配置相应功能
    // 是否支持加密
    if (features & TJP_FEATURE_ENCRYPTION) {
        TJPLOG_INFO(@"启用加密功能");
        // 配置加密
    } else {
        TJPLOG_INFO(@"禁用加密功能");
        // 禁用加密
    }
    
    // 示例：判断是否支持压缩
    if (features & TJP_FEATURE_COMPRESSION) {
        TJPLOG_INFO(@"启用压缩功能");
        // 配置压缩
    } else {
        TJPLOG_INFO(@"禁用压缩功能");
        // 禁用压缩
    }
    
    // 配置其他功能
}


- (void)sendAckForPacket:(TJPParsedPacket *)packet messageCategory:(TJPMessageCategory)messageCategory {
    // 创建ACK消息
    uint32_t ackSeq = [self.seqManager nextSequenceForCategory:messageCategory];
    
    TJPFinalAdavancedHeader header;
    memset(&header, 0, sizeof(TJPFinalAdavancedHeader));
    
    // 注意：需要转换为网络字节序
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeACK);
    header.sequence = htonl(ackSeq);
    header.timestamp = htonl((uint32_t)[[NSDate date] timeIntervalSince1970]);
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons([TJPMessageBuilder sessionIDFromUUID:self.sessionId]);
    
    
    // ACK消息体 - 包含被确认的序列号
    NSMutableData *ackData = [NSMutableData data];
    uint32_t originalSeq = htonl(packet.sequence);
    [ackData appendBytes:&originalSeq length:sizeof(uint32_t)];
    
    header.bodyLength = htonl((uint32_t)ackData.length);
    
    // 计算校验和
    uint32_t checksum = [TJPNetworkUtil crc32ForData:ackData];
    header.checksum = htonl(checksum);
    
    TJPLOG_INFO(@"sendAckForPacket方法中计算的校验和 CRC32: %u", checksum);
    
    
    // 构建完整的ACK数据包
    NSMutableData *ackPacket = [NSMutableData dataWithBytes:&header length:sizeof(TJPFinalAdavancedHeader)];
    [ackPacket appendData:ackData];
    
    // 发送ACK数据包
    [self.connectionManager sendData:ackPacket withTimeout:-1 tag:ackSeq];
    
    TJPLOG_INFO(@"已发送 %@ ACK确认包，确认序列号: %u", [self messageTypeToString:packet.messageType], packet.sequence);
}

- (void)handleACKForSequence:(uint32_t)sequence {
   dispatch_async(self.sessionQueue, ^{
       TJPMessageContext *context = self.pendingMessages[@(sequence)];

       if (context) {
           switch (context.messageType) {
               case TJPMessageTypeNormalData:
                   TJPLOG_INFO(@"普通消息 %u 已被确认", sequence);
                   break;
               case TJPMessageTypeControl:
                   TJPLOG_INFO(@"控制消息 %u 已被确认", sequence);
                   break;
               default:
                   TJPLOG_INFO(@"消息 %u 已被确认", sequence);
                   break;
           }
           // 从待确认消息列表中移除
           [self.pendingMessages removeObjectForKey:@(sequence)];
           
           // 取消对应的重传计时器
           NSString *timerKey = [NSString stringWithFormat:@"retry_%u", sequence];
           dispatch_source_t timer = self.retransmissionTimers[timerKey];
           if (timer) {
               dispatch_source_cancel(timer);
               [self.retransmissionTimers removeObjectForKey:timerKey];
           }
           
       } else if ([self.heartbeatManager isHeartbeatSequence:sequence]) {
           // 处理心跳ACK
           [self.heartbeatManager heartbeatACKNowledgedForSequence:sequence];
       } else {
           TJPLOG_INFO(@"收到未知消息的ACK，序列号: %u", sequence);
       }
   });
}

- (void)handleHeartbeatTimeout:(NSNotification *)notification {
   id<TJPSessionProtocol> session = notification.userInfo[@"session"];
   if (session == self) {
       dispatch_async(self.sessionQueue, ^{
           TJPLOG_WARN(@"心跳超时，断开连接");
           [self disconnectWithReason:TJPDisconnectReasonHeartbeatTimeout];
       });
   }
}

- (TJPConnectEvent)eventForTargetState:(TJPConnectState)targetState {
   // 定义状态到事件的映射规则
   static NSDictionary<NSString *, NSString *> *stateEventMap;
   static dispatch_once_t onceToken;
   dispatch_once(&onceToken, ^{
       stateEventMap = @{
           TJPConnectStateDisconnected: TJPConnectEventDisconnectComplete,
           TJPConnectStateConnecting: TJPConnectEventConnect,
           TJPConnectStateConnected: TJPConnectEventConnectSuccess,
           TJPConnectStateDisconnecting: TJPConnectEventDisconnect
       };
   });
   return stateEventMap[targetState];
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
       case TJPDisconnectReasonConnectionTimeout:
           return @"连接超时";
       case TJPDisconnectReasonSocketError:
           return @"套接字错误";
       case TJPDisconnectReasonAppBackgrounded:
           return @"应用进入后台";
       case TJPDisconnectReasonForceReconnect:
           return @"强制重连";
       default:
           return @"未知原因";
   }
}

- (NSString *)messageTypeToString:(uint16_t)messageType {
    switch (messageType) {
        case TJPMessageTypeNormalData:
            return @"普通消息";
        case TJPMessageTypeHeartbeat:
            return @"心跳";
        case TJPMessageTypeACK:
            return @"确认";
        case TJPMessageTypeControl:
            return @"控制消息";
        default:
            return @"未知类型";
    }
}


- (void)handleDisconnectStateTransition {
    //先检查当前状态
    TJPConnectState currentState = self.stateMachine.currentState;
    
    //根据当前状态决定如何处理
    if ([currentState isEqualToString:TJPConnectStateDisconnecting]) {
        [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
    }else if ([currentState isEqualToString:TJPConnectStateConnected] || [currentState isEqualToString:TJPConnectStateConnecting]) {
        // 连接中或已连接，需要完整的断开流程
        [self.stateMachine sendEvent:TJPConnectEventDisconnect];
        [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
    } else if ([currentState isEqualToString:TJPConnectStateDisconnected]) {
        // 已经断开，无需处理
        TJPLOG_INFO(@"已在断开状态，无需处理状态转换");
    }
}

- (void)handleDisconnectError:(NSError *)err {
    // 判断错误类型
    if (err) {
        TJPLOG_INFO(@"连接已断开，原因: %@", err.localizedDescription);
        // 设置断开原因
        if (err.code == NSURLErrorNotConnectedToInternet) {
            self.disconnectReason = TJPDisconnectReasonNetworkError;
            TJPLOG_INFO(@"网络错误：无法连接到互联网");
        } else {
            self.disconnectReason = TJPDisconnectReasonSocketError;
            TJPLOG_INFO(@"连接错误：%@", err.localizedDescription);
        }
    } else {
        // 如果没有错误，则正常处理断开
        TJPLOG_INFO(@"连接已正常断开");

        // 如果没有明确设置，这里可能是用户主动断开
        if (self.disconnectReason == TJPDisconnectReasonNone) {
            self.disconnectReason = TJPDisconnectReasonUserInitiated;
        }
    }
}




@end

