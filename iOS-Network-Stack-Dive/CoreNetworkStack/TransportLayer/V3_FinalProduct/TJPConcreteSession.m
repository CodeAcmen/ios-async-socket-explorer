//
//  TJPConcreteSession.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPConcreteSession.h"
#import <GCDAsyncSocket.h>

#import "TJPNetworkConfig.h"
#import "JZNetworkDefine.h"

#import "TJPNetworkCoordinator.h"
#import "TJPReconnectPolicy.h"
#import "TJPDynamicHeartbeat.h"
#import "TJPMessageParser.h"
#import "TJPMessageContext.h"
#import "TJPParsedPacket.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkUtil.h"
#import "TJPConnectStateMachine.h"



static const NSTimeInterval kDefaultRetryInterval = 10;

@interface TJPConcreteSession () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t internalQueu;

/// 连接状态机
@property (nonatomic, strong) TJPConnectStateMachine *stateMachine;

/// 重试策略
@property (nonatomic, strong) TJPReconnectPolicy *reconnectPolicy;
/// 动态心跳
@property (nonatomic, strong) TJPDynamicHeartbeat *heartbeatManager;
/// 序列号管理
@property (nonatomic, strong) TJPSequenceManager *seqManager;

/// 协议处理
@property (nonatomic, strong) TJPMessageParser *parser;
/// 缓冲区
@property (nonatomic, strong) NSMutableData *buffer;

/// 待确认消息
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPMessageContext *> *pendingMessages;


@end

@implementation TJPConcreteSession

#pragma mark - Lifecycle
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config {
    if (self = [super init]) {
        _sessionId = [[NSUUID UUID] UUIDString];
        _internalQueu = dispatch_queue_create("com.concreteSession.tjp.interalQueue", DISPATCH_QUEUE_CONCURRENT);
        [self setupComponentWithConfig:config];
        
        _stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
        [self setupStateMachine];
        
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
    _reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:config.maxRetry baseDelay:config.baseDelay qos:TJPNetworkQoSDefault];
    
    //初始化心跳管理
    _heartbeatManager = [[TJPDynamicHeartbeat alloc] initWithBaseInterval:config.heartbeat seqManager:_seqManager];
}

//制定转换规则
- (void)setupStateMachine {
    //增加强制断开规则：允许从任何状态直接进入 Disconnected
    [_stateMachine addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];

    
    //未连接->连接中 连接事件
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    //连接中->已连接 连接成功事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    //连接中->未连接 连接失败事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailed];
    //已连接->断开中 断开连接事件
    [_stateMachine addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    //断开中->未连接 断开完成事件
    [_stateMachine addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];
    
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
    dispatch_barrier_async(self->_internalQueu, ^{
        //通过状态机检查当前状态
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateDisconnected]) {
            TJPLOG_INFO(@"当前状态无法连接主机,当前状态为: %@", self.stateMachine.currentState);
            return;
        }
        
        //触发连接事件
        [self.stateMachine sendEvent:TJPConnectEventConnect];

        //创建新的Socket实例
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[TJPNetworkCoordinator shared].ioQueue];
        
        __weak typeof(self) weakSelf = self;
        [self.reconnectPolicy attemptConnectionWithBlock:^{
            NSError *error = nil;
            if (![weakSelf.socket connectToHost:host onPort:port error:&error]) {
                [weakSelf handleError:error];
            }
        }];
    });
}

/// 发送消息
- (void)sendData:(NSData *)data {
    dispatch_barrier_async(self->_internalQueu, ^{
        if (![self.stateMachine.currentState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_INFO(@"当前状态发送消息失败,当前状态为: %@", self.stateMachine.currentState);
        }
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
        
        //发送消息
        [self.socket writeData:packet withTimeout:-1 tag:context.sequence];
    });
}

/// 断开连接原因
- (void)disconnectWithReason:(TJPDisconnectReason)reason {
    dispatch_barrier_async(self->_internalQueu, ^{
        [self.socket disconnect];

        //触发断开连接完成事件
        [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        
        //清理资源
        [self.heartbeatManager stopMonitoring];
        [self.pendingMessages removeAllObjects];
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

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_barrier_async(self->_internalQueu, ^{
        //触发连接成功事件
        [self.stateMachine sendEvent:TJPConnectEventConnect];
        
        //启动TLS
        NSDictionary *tlsSettings = @{(id)kCFStreamSSLPeerName: host};
        [sock startTLS:tlsSettings];
        
        //启动心跳
        [self.heartbeatManager startMonitoringForSession:self];
        
        //开始读取数据
        [sock readDataWithTimeout:-1 tag:0];
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    dispatch_async([TJPNetworkCoordinator shared].parseQueue, ^{
        //缓冲区添加数据
        [self.parser feedData:data];
        
        //解析数据
        while ([self.parser hasCompletePacket]) {
            TJPParsedPacket *packet = [self.parser nextPacket];
            //处理数据
            [self processReceivedPacket:packet];
        }
        [sock readDataWithTimeout:-1 tag:0];
    });
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    dispatch_barrier_async(self->_internalQueu, ^{
        //触发断开连接完成事件
        [self.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
        //准备重连
        [self.reconnectPolicy attemptConnectionWithBlock:^{
            [self connectToHost:self.socket.connectedHost port:self.socket.connectedPort];
        }];
    });
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dispatch_time(DISPATCH_TIME_NOW, kDefaultRetryInterval) * NSEC_PER_SEC)), self->_internalQueu, ^{
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
    // ✅ 统一处理所有 ACK
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
    dispatch_async(self->_internalQueu, ^{
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


#pragma mark - Lazy
- (NSMutableDictionary<NSNumber *, TJPMessageContext *> *)pendingMessages {
    if (!_pendingMessages) {
        _pendingMessages = [NSMutableDictionary dictionary];
    }
    return _pendingMessages;
}



@end

