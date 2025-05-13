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

#import "TJPNetworkCoordinator.h"
#import "TJPReconnectPolicy.h"
#import "TJPDynamicHeartbeat.h"
#import "TJPMessageParser.h"
#import "TJPMessageContext.h"
#import "TJPParsedPacket.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkUtil.h"
#import "TJPConnectStateMachine.h"
#import "TJPNetworkCondition.h"
#import "TJPMetricsConsoleReporter.h"



static const NSTimeInterval kDefaultRetryInterval = 10;

@interface TJPConcreteSession () <GCDAsyncSocketDelegate, TJPReconnectPolicyDelegate>

@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;

/// 动态心跳
@property (nonatomic, strong) TJPDynamicHeartbeat *heartbeatManager;
/// 序列号管理
@property (nonatomic, strong) TJPSequenceManager *seqManager;

/// 协议处理
@property (nonatomic, strong) TJPMessageParser *parser;
/// 缓冲区
@property (nonatomic, strong) NSMutableData *buffer;



@end

@implementation TJPConcreteSession

- (void)dealloc {
    TJPLogDealloc();
}

#pragma mark - Lifecycle
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config {
    if (self = [super init]) {
        _config = config;
        _autoReconnectEnabled = YES;
        _sessionId = [[NSUUID UUID] UUIDString];
        
        // 创建专用队列（串行，中等优先级）
        _socketQueue = dispatch_queue_create("com.concreteSession.tjp.socketQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_socketQueue, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        
        
        // 初始化状态机（初始状态：断开连接）
        _stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected setupStandardRules:YES];
        [self setupStateMachine];

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
    //序列号管理
    _seqManager = [[TJPSequenceManager alloc] init];
    
    //初始化协议解析器
    _parser = [[TJPMessageParser alloc] init];
    _buffer = [NSMutableData data];
    
    //初始化重连策略
    _reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:config.maxRetry baseDelay:config.baseDelay qos:TJPNetworkQoSDefault delegate:self];
    
    //初始化心跳管理
    _heartbeatManager = [[TJPDynamicHeartbeat alloc] initWithBaseInterval:config.heartbeat seqManager:_seqManager session:self];
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
            // 更新心跳管理器的 session 引用 并启动心跳
            [strongSelf.heartbeatManager updateSession:strongSelf];
            // 如果有积压消息 发送积压消息
            [strongSelf flushPendingMessages];
            //通知代理
            [self notifyDelegateOfStateChange];
        } else if ([newState isEqualToString:TJPConnectStateDisconnected]) {
            // 断开连接，停止心跳
            [strongSelf.heartbeatManager stopMonitoring];
        }
    }];
}


#pragma mark - TJPSessionProtocol
/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self->_socketQueue, ^{
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

        //创建新的Socket实例
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
                
        // 执行实际连接操作
        NSError *error = nil;
        if (![self.socket connectToHost:host onPort:port error:&error]) {
            [self handleError:error];
            // 如果连接立即失败，直接返回
            return;
        }
        
        //新增连接超时处理
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            // 检查连接状态 - 如果30秒后仍处于"连接中"状态，则认为连接超时
            if ([strongSelf.stateMachine.currentState isEqualToString:TJPConnectStateConnecting]) {
                TJPLOG_ERROR(@"连接超时（30秒），自动断开");
                
                // 设置断开原因为超时
                strongSelf.disconnectReason = TJPDisconnectReasonConnectionTimeout;
                
                // 断开连接
                [strongSelf.socket disconnect];
                
                // 状态转换为连接失败
                [strongSelf.stateMachine sendEvent:TJPConnectEventConnectFailure];
                
                // 只有启用了自动重连且不是用户主动断开的情况下才尝试重连
                if (strongSelf.autoReconnectEnabled) {
                    [strongSelf.reconnectPolicy attemptConnectionWithBlock:^{
                        [strongSelf connectToHost:strongSelf.host port:strongSelf.port];
                    }];
                }
            }
        });
        
    });
}

/// 发送消息
- (void)sendData:(NSData *)data {
    dispatch_async(self->_socketQueue, ^{
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_INFO(@"当前状态发送消息失败,当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        TJPLOG_INFO(@"session 准备构造数据包");
        //创建序列号
        uint32_t seq = [self.seqManager nextSequenceForCategory:TJPMessageCategoryNormal];
        
        //构造协议包  实际通过Socket发送的协议包(协议头+原始数据)
        NSData *packet = [self _buildPacketWithData:data seq:seq];
        
        //消息的上下文,用于跟踪消息状态(发送时间,重试次数,序列号)
        TJPMessageContext *context = [TJPMessageContext contextWithData:data seq:seq];
        //存储待确认消息
        self.pendingMessages[@(context.sequence)] = context;
        
        //设置超时重传
        [self scheduleRetransmissionForSequence:context.sequence];
        
        TJPLOG_INFO(@"session 消息即将发出");
        //发送消息
        [self.socket writeData:packet withTimeout:-1 tag:context.sequence];
    });
}

/// 发送心跳包
- (void)sendHeartbeat:(NSData *)heartbeatData {
    dispatch_async(self->_socketQueue, ^{
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_INFO(@"当前状态发送心跳包失败, 当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        TJPLOG_INFO(@"session 正在发送心跳包");
        [self.socket writeData:heartbeatData withTimeout:-1 tag:0];        
    });
}

- (void)disconnectWithReason:(TJPDisconnectReason)reason {
    dispatch_async(self->_socketQueue, ^{
        // 避免重复断开
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
            TJPLOG_INFO(@"当前已是断开状态，无需再次断开");
            return;
        }
        
        //存储断开原因
        self.disconnectReason = reason;
        
        // 根据当前状态选择正确的状态转换路径
//        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnected] ||
//            [self.stateMachine.currentState isEqualToString:TJPConnectStateConnecting]) {
//            // 如果当前是连接或连接中状态，先进入断开中状态
//            [self.stateMachine sendEvent:TJPConnectEventDisconnect];
//        }
        [self.stateMachine sendEvent:TJPConnectEventDisconnect];
        
        //断开socket
        [self.socket disconnect];
        
        //停止心跳
        [self.heartbeatManager stopMonitoring];
        
        //清理资源
        [self.pendingMessages removeAllObjects];
        
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
    dispatch_async(self->_socketQueue, ^{
        //重连之前确保连接断开
        [self.socket disconnect];
                
        // 检查当前连接状态
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
            // 当前是断开状态，直接重新连接
            TJPLOG_INFO(@"当前状态为断开，重新连接...");
            [self.reconnectPolicy attemptConnectionWithBlock:^{
                [self connectToHost:self.host port:self.port];
            }];
        } else if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnecting]) {
            // 当前是连接中，等待连接完成
            TJPLOG_INFO(@"当前状态为连接中，等待连接完成...");
        } else if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            // 当前已连接，需要先断开连接然后再重新连接
            TJPLOG_INFO(@"当前状态为已连接，断开连接重新连接...");
            [self disconnectWithReason:TJPDisconnectReasonForceReconnect];
            [self.reconnectPolicy attemptConnectionWithBlock:^{
                [self connectToHost:self.socket.connectedHost port:self.socket.connectedPort];
            }];
        } else {
            TJPLOG_WARN(@"未知连接状态: %@", self.stateMachine.currentState);
        }
        
        // 重置连接相关的状态
        [self resetConnection];
    });
}

- (void)prepareForRelease { 
    [self.heartbeatManager stopMonitoring];
    [self.pendingMessages removeAllObjects];
    [TJPMetricsConsoleReporter stop];
}




#pragma mark - TJPReconnectPolicyDelegate
- (void)reconnectPolicyDidReachMaxAttempts:(TJPReconnectPolicy *)reconnectPolicy {
    TJPLOG_ERROR(@"最大重连次数已达到，连接失败");
    // 停止重连尝试
    [self.reconnectPolicy stopRetrying];
    
    // 将状态机转为断开状态
    [self.stateMachine sendEvent:TJPConnectEventConnectFailure];
    
    // 关闭 socket 连接
    [self.socket disconnect];
    
    // 停止心跳
    [self.heartbeatManager stopMonitoring];
    
    //清理资源
    [self.pendingMessages removeAllObjects];
    
    // 停止网络指标监控
    [TJPMetricsConsoleReporter stop];
    
    
    TJPLOG_INFO(@"当前连接退出");
}

- (NSString *)getCurrentConnectionState {
    return self.stateMachine.currentState;
}



#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self->_socketQueue, ^{
        TJPLOG_INFO(@"连接成功 准备给状态机发送连接成功事件");
        self.isReconnecting = NO;

        //触发连接成功事件 状态转换为"已连接"
        [self.stateMachine sendEvent:TJPConnectEventConnectSuccess];
        
        //启动TLS  Mock时将TLS关闭
//        NSDictionary *tlsSettings = @{(id)kCFStreamSSLPeerName: host};
//        [sock startTLS:tlsSettings];
                
        //开始读取数据
        [sock readDataWithTimeout:-1 tag:0];
        
#if DEBUG
    // 在连接成功后启动网络指标监控
    [TJPMetricsConsoleReporter start];
#endif
        
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    dispatch_async([TJPNetworkCoordinator shared].parseQueue, ^{
        TJPLOG_INFO(@"读取到数据 缓冲区准备添加数据");
        //缓冲区添加数据
        [self.parser feedData:data];
        
        //解析数据
        while ([self.parser hasCompletePacket]) {
            TJPLOG_INFO(@"开始解析数据");
            TJPParsedPacket *packet = [self.parser nextPacket];
            if (!packet) {
                TJPLOG_INFO(@"数据解析出错 TJPParsedPacket为空,请检查 后续流程停止");
                return;
            }
            //处理数据
            [self processReceivedPacket:packet];
        }
        [sock readDataWithTimeout:-1 tag:0];
    });
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    dispatch_async(self->_socketQueue, ^{
        self.isReconnecting = NO;

        //处理状态转换
        [self handleDisconnectStateTransition];
        
        //处理错误并设置断开原因
        [self handleDisconnectError:err];
        
        //清理资源
        [self cleanupAfterDisconnect];
        
        //处理重连策略
        [self handleReconnectionAfterDisconnect];
    });
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

- (void)cleanupAfterDisconnect {
    // 清理资源
    [self.heartbeatManager stopMonitoring];
    [self.pendingMessages removeAllObjects];
}


- (void)handleReconnectionAfterDisconnect {
    // 检查网络状态，只有在网络可达时才尝试重连
    if ([[TJPNetworkCoordinator shared].reachability currentReachabilityStatus] != NotReachable &&
         (self.disconnectReason == TJPDisconnectReasonNetworkError ||
          self.disconnectReason == TJPDisconnectReasonHeartbeatTimeout ||
          self.disconnectReason == TJPDisconnectReasonIdleTimeout)) {
         
         // 准备重连
         [self.reconnectPolicy attemptConnectionWithBlock:^{
             // 再次检查状态
             if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
                 [self connectToHost:self.host port:self.port];
             }
         }];
     }
}

// 断开连接优化
- (void)disconnect {
    [self disconnectWithReason:TJPDisconnectReasonUserInitiated];
}

- (void)networkDidBecomeAvailable {
    dispatch_async(self->_socketQueue, ^{
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
            [self connectToHost:self.host port:self.port];
        }
    });
}

- (void)networkDidBecomeUnavailable {
    dispatch_async(self->_socketQueue, ^{
        // 如果当前连接中或已连接，则标记为网络错误并断开
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateConnecting] ||
            [self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            
            [self disconnectWithReason:TJPDisconnectReasonNetworkError];
        }
    });
}

- (void)forceDisconnect { 
    
}


// 心跳超时处理
- (void)handleHeartbeatTimeout:(NSNotification *)notification {
    id<TJPSessionProtocol> session = notification.userInfo[@"session"];
    if (session == self) {
        dispatch_async(self->_socketQueue, ^{
            TJPLOG_INFO(@"心跳超时，断开连接");
            [self disconnectWithReason:TJPDisconnectReasonHeartbeatTimeout];
        });
    }
}


#pragma mark - Public Method




#pragma mark - Private Method
- (NSData *)_buildPacketWithData:(NSData *)data seq:(uint32_t)seq {
    // 初始化协议头
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeNormalData); // 普通消息类型
    header.sequence = htonl(seq);
    header.bodyLength = htonl((uint32_t)data.length);
    
    // 计算数据体的CRC32
    uint32_t checksum = [TJPNetworkUtil crc32ForData:data];
    header.checksum = htonl(checksum);  // 注意要转换为网络字节序
    
    // 构建完整协议包
    NSMutableData *packet = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [packet appendData:data];
    return packet;
}

//超时重传
- (void)scheduleRetransmissionForSequence:(uint32_t)sequence {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dispatch_time(DISPATCH_TIME_NOW, kDefaultRetryInterval) * NSEC_PER_SEC)), self->_socketQueue, ^{
        if (self.pendingMessages[@(sequence)]) {
            TJPLOG_INFO(@"消息 %u 超时未确认, 尝试重传", sequence);
            [self resendPacket:self.pendingMessages[@(sequence)]];
        }
    });
}

//重传消息
- (void)resendPacket:(TJPMessageContext *)context {
    NSData *packet = [context buildRetryPacket];
    [self.socket writeData:packet withTimeout:-1 tag:context.sequence];
}

//处理消息
- (void)processReceivedPacket:(TJPParsedPacket *)packet {
//    TJPLOG_INFO(@"接收到数据包 消息类型为 %hu", packet.messageType);
    switch (packet.messageType) {
        case TJPMessageTypeNormalData:
            [self handleDataPacket:packet];
            break;
        case TJPMessageTypeHeartbeat:
            [self.heartbeatManager heartbeatACKNowledgedForSequence:packet.sequence];
            break;
        case TJPMessageTypeACK:
            [self handleACKForSequence:packet.sequence];
            break;
        default:
            TJPLOG_INFO(@"收到未知消息类型 %u", packet.sequence);
            break;
    }
}


//处理普通数据包
- (void)handleDataPacket:(TJPParsedPacket *)packet {
    TJPLOG_INFO(@"接收到 普通消息 数据包并进行处理");
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveRawData:)]) {
        [self.delegate session:self didReceiveRawData:packet.payload];
    }
}

//处理ACK确认
- (void)handleACKForSequence:(uint32_t)sequence {
    TJPLOG_INFO(@"接收到 ACK 数据包并进行处理");
    
    // 检查是否已处理过这个ACK
    static NSMutableSet *processedACKs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processedACKs = [NSMutableSet set];
    });

    // 生成唯一的ACK标识符
    NSString *ackId = [NSString stringWithFormat:@"%u", sequence];
    
    // 如果已处理过，直接返回
    if ([processedACKs containsObject:ackId]) {
        return;
    }
    
    // 将此ACK标记为已处理
    [processedACKs addObject:ackId];

    // 首先检查是否是普通消息的ACK
    if ([self.pendingMessages objectForKey:@(sequence)]) {
        // 普通消息 ACK：移除待确认队列
        TJPLOG_INFO(@"处理普通消息ACK，序列号: %u", sequence);
        [self.pendingMessages removeObjectForKey:@(sequence)];
    }else if ([self.seqManager isSequenceForCategory:sequence category:TJPMessageCategoryHeartbeat]) {
        // 检查是否是心跳的ACK
        TJPLOG_INFO(@"处理心跳ACK，序列号: %u", sequence);
        [self.heartbeatManager heartbeatACKNowledgedForSequence:sequence];
    }
    else {
        // 未知ACK
        TJPLOG_WARN(@"收到未知ACK，序列号: %u", sequence);
    }
    
    // 定期清理处理过的ACK集合，避免无限增长
    if (processedACKs.count > 1000) {
        [processedACKs removeAllObjects];
    }
}

- (void)handleError:(NSError *)error {
    TJPLOG_INFO(@"连接错误: %@", error.description);
    [self disconnectWithReason:TJPDisconnectReasonNetworkError];
}

- (void)flushPendingMessages {
    dispatch_async(self->_socketQueue, ^{
        for (NSNumber *seq in self.pendingMessages) {
            TJPMessageContext *context = self.pendingMessages[seq];
            [self resendPacket:context];
        }
    });
}

- (void)resetConnection {
    [self.heartbeatManager.sequenceManager resetSequence];
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


- (void)notifyDelegateOfStateChange {
    
}


#pragma mark - Lazy
- (NSMutableDictionary<NSNumber *, TJPMessageContext *> *)pendingMessages {
    if (!_pendingMessages) {
        _pendingMessages = [NSMutableDictionary dictionary];
    }
    return _pendingMessages;
}



@end

