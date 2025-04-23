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
        _autoReconnectEnabled = YES;
        _sessionId = [[NSUUID UUID] UUIDString];
        // 创建专用队列（串行，中等优先级）
        _socketQueue = dispatch_queue_create("com.concreteSession.tjp.socketQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_socketQueue, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        
        
        // 初始化状态机（初始状态：断开连接）
        _stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
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
    //增加强制断开规则：允许从任何状态直接进入 Disconnected
    [_stateMachine addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    

    //状态保留规则
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];

    
    //网络错误
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventNetworkError];

    
    /*    状态流转规则     */
    //未连接->连接中 连接事件
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    //连接中->已连接 连接成功事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    //连接中->未连接 连接失败事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailed];
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailed];
    
    //已连接->断开中 断开连接事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    [_stateMachine addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    
    //断开中->未连接 断开完成事件
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];
    /*    ----------     */

        
    //注册状态变更回调
    __weak typeof(self) weakSelf = self;
    [_stateMachine onStateChange:^(TJPConnectState  _Nonnull oldState, TJPConnectState  _Nonnull newState) {
        TJPLOG_INFO(@"连接状态变更: 旧状态:%@ -> 新状态:%@", oldState, newState);
        if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(session:stateChanged:)]) {
            [weakSelf.delegate session:weakSelf stateChanged:newState];
        }
        
        if ([newState isEqualToString:TJPConnectStateConnected]) {
            [weakSelf flushPendingMessages];
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
        
//        __weak typeof(self) weakSelf = self;
//        [self.reconnectPolicy attemptConnectionWithBlock:^{
//            NSError *error = nil;
//            if (![weakSelf.socket connectToHost:host onPort:port error:&error]) {
//                [weakSelf handleError:error];
//            }
//        }];
        
        // 执行实际连接操作
        NSError *error = nil;
        if (![self.socket connectToHost:host onPort:port error:&error]) {
            [self handleError:error];
        }
        
#if DEBUG
    //开始监听网络指标
    [TJPMetricsConsoleReporter start];
#endif
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
        uint32_t seq = [self.seqManager nextSequence];
        
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
    [self.stateMachine sendEvent:TJPConnectEventConnectFailed];
    
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



#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self->_socketQueue, ^{
        TJPLOG_INFO(@"连接成功 准备给状态机发送连接成功事件");
        //触发连接成功事件 状态转换为"已连接"
        [self.stateMachine sendEvent:TJPConnectEventConnectSuccess];
        
        
        //启动TLS  Mock时将TLS关闭
//        NSDictionary *tlsSettings = @{(id)kCFStreamSSLPeerName: host};
//        [sock startTLS:tlsSettings];
        
        //启动心跳
        [self.heartbeatManager startMonitoring];
        
        //开始读取数据
        [sock readDataWithTimeout:-1 tag:0];
        
        //通知代理
        [self notifyDelegateOfStateChange];
        
        //发送积压消息
        [self flushPendingMessages];
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
            
            // 触发断开连接事件，进入 Disconnecting 状态
            [self.stateMachine sendEvent:TJPConnectEventDisconnect];
            // 在 Disconnecting 状态下触发断开完成事件
            [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
            
        } else {
            // 如果没有错误，则正常处理断开
            TJPLOG_INFO(@"连接已正常断开");

            // 触发断开连接事件，进入 Disconnecting 状态
            [self.stateMachine sendEvent:TJPConnectEventDisconnect];
            
            // 在 Disconnecting 状态下触发断开完成事件
            [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        }
        
        // 清理资源
         [self.heartbeatManager stopMonitoring];
         [self.pendingMessages removeAllObjects];
                
        // 检查网络状态，只有在网络可达时才尝试重连
        if ([[TJPNetworkCoordinator shared].reachability currentReachabilityStatus] != NotReachable &&
             (self.disconnectReason == TJPDisconnectReasonNetworkError ||
              self.disconnectReason == TJPDisconnectReasonHeartbeatTimeout ||
              self.disconnectReason == TJPDisconnectReasonIdleTimeout)) {
             
             // 准备重连
             [self.reconnectPolicy attemptConnectionWithBlock:^{
                 [self connectToHost:self.host port:self.port];
             }];
         }
    });
}

// 断开连接优化
- (void)disconnect {
    [self disconnectWithReason:TJPDisconnectReasonUserInitiated];
}

- (void)networkDidBecomeAvailable {
    dispatch_async(self->_socketQueue, ^{
        // 只有当前状态为断开状态且启用了自动重连才尝试重连
        if ([self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected] &&
            self.autoReconnectEnabled &&
            self.disconnectReason != TJPDisconnectReasonUserInitiated) {
            
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
    header.checksum = [TJPNetworkUtil crc32ForData:data];
    
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
    TJPLOG_INFO(@"接收到数据包 消息类型为 %hu", packet.messageType);
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
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveData:)]) {
        [self.delegate session:self didReceiveData:packet.payload];
    }
}

//处理ACK确认
- (void)handleACKForSequence:(uint32_t)sequence {
    // 统一处理所有 ACK
    if ([self.pendingMessages objectForKey:@(sequence)]) {
        // 普通消息 ACK：移除待确认队列
        [self.pendingMessages removeObjectForKey:@(sequence)];
    } else if (sequence == [self.heartbeatManager.sequenceManager currentSequence]) {
        // 心跳 ACK：通知心跳管理器
        [self.heartbeatManager heartbeatACKNowledgedForSequence:sequence];
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

