//
//  TJPNetworkManagerV2.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPNetworkManagerV2.h"
#import <Reachability/Reachability.h>
#import <GCDAsyncSocket.h>
#import <zlib.h>

#import "TJPNetworkProtocol.h"
#import "JZNetworkDefine.h"
#import "TJPNETError.h"
#import "TJPNETErrorHandler.h"

static const NSInteger kMaxReconnectAttempts = 5;
//一般应用来说 30秒的最大延迟时间基本够用
static const NSTimeInterval kMaxReconnectDelay = 30;


@interface TJPNetworkManagerV2 () {
    //网络状态
    Reachability *_networkReachability;
    //网络队列
    dispatch_queue_t _networkQueue;
    //处理队列
    dispatch_queue_t _parseQueue;
    //重试次数
    NSInteger _reconnectAttempt;
    //当前协议头
    TJPAdavancedHeader _currentHeader;
}

@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

//缓冲区
@property (nonatomic, strong) NSMutableData *parseBuffer;
//标志位
@property (nonatomic, assign) BOOL isParsingHeader;

//待确认心跳包
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;

//心跳机制
@property (nonatomic, strong) dispatch_source_t heartbeatTimer;
@property (nonatomic, strong) NSDate *lastHeartbeatTime;

@end

@implementation TJPNetworkManagerV2
#pragma mark - Instancetype
+ (instancetype)shared {
    static TJPNetworkManagerV2 *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPNetworkManagerV2 alloc] init];
    });
    return instance;
}

- (void)dealloc {
    [self stopHeartbeat];
}

- (instancetype)init {
    if (self = [super init]) {
        _currentSequence = 0;
        _reconnectAttempt = 0;
        _isParsingHeader = YES;

        _networkQueue = dispatch_queue_create("com.tjp.networkManager.netQueue", DISPATCH_QUEUE_SERIAL);
        _parseQueue = dispatch_queue_create("com.tjp.networkManager.parseQueue", DISPATCH_QUEUE_SERIAL);
        
        [self setupNetworkReachability];
    }
    return self;
}

#pragma mark - Public Method
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self->_networkQueue, ^{
        self.host = host;
        self.port = port;
        
        [self disconnect];
        
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self->_networkQueue];
        NSError *error = nil;
        if (![self.socket connectToHost:host onPort:port error:&error]) {
            [self handleError:error];
        }
    });
}

- (void)sendData:(NSData *)data {
    dispatch_async(self->_networkQueue, ^{
        if (!self.isConnected) return;
        
        NSData *packet = [self _buildPacketWithType:TJPMessageTypeNormalData data:data];
        
        [self.socket writeData:packet withTimeout:-1 tag:self->_currentSequence];
        
        //加入队列
        [self addPendingMessage:data forSequence:self->_currentSequence];
        //检查超时
        [self checkPendingMessageTimeoutForSequence:self->_currentSequence];

    });
}

//断线重连策略
- (void)scheduleReconnect {
    if (_reconnectAttempt >= kMaxReconnectAttempts) {
        TJPLOG_ERROR(@"已达到最大重连次数,重连停止");
        [self postNotification:kNetworkFatalErrorNotification];
        return;
    };
    
    //延迟时间=指数退避策略+随机抖动优化  避免服务器惊群效应
    NSInteger baseDelay = 2;
    NSTimeInterval delay = pow(baseDelay, _reconnectAttempt) + arc4random_uniform(3);
    delay = MIN(delay, kMaxReconnectDelay);

    TJPLOG_WARN(@"%ld秒后尝试第%ld次重连", (long)delay, _reconnectAttempt + 1);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self->_networkQueue, ^{
        if ([self->_networkReachability isReachable]) {
            [self connectToHost:self.host port:self.port];
        } else {
            [self scheduleReconnect];
        }
    });
    _reconnectAttempt++;
}

- (void)resetConnection {
    //断开连接并重置
    [self disconnect];
    
    [self.pendingHeartbeats removeAllObjects];
    [self.pendingMessages removeAllObjects];
    
    //重新连接
    [self scheduleReconnect];
}


#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    TJPLOG_INFO(@"已连接 %@:%d", host, port);
    
    self.isConnected = YES;
    _reconnectAttempt = 0;
    
    //开启TLS/SSL
    NSDictionary<NSString *, NSObject *> *settings = @{(id)kCFStreamSSLPeerName: host};
    [sock startTLS:settings];
    
    //开始心跳
    [self startHeartbeat];
    
    //开始接收数据
    [sock readDataWithTimeout:-1 tag:0];
}

//接收到数据时会触发
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    [self.parseBuffer appendData:data];
    
    while (YES) {
        if ([self isParsingHeaderSafe]) {
            if (self.parseBuffer.length < sizeof(TJPAdavancedHeader)) break;
            
            TJPAdavancedHeader currentHeader = {0};
            //解析头部
            [self.parseBuffer getBytes:&currentHeader length:sizeof(TJPAdavancedHeader)];
            
            //校验魔数
            if (ntohl(currentHeader.magic) != kProtocolMagic) {
                //魔数校验失败
                [self handleInvalidData];
                [self resetParse];
                return;
            }
            _currentHeader = currentHeader;
            [self setIsParsingHeader:NO];
            // 移除已处理的Header数据
            [self.parseBuffer replaceBytesInRange:NSMakeRange(0, sizeof(TJPAdavancedHeader)) withBytes:NULL length:0];
        }
        
        //读取消息体
        uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
        if (self.parseBuffer.length < bodyLength) break;
        
        //处理消息体
        NSData *payload = [self.parseBuffer subdataWithRange:NSMakeRange(0, bodyLength)];
        [self processMessage:_currentHeader payload:payload];
        
        //移除已处理部分
        [self.parseBuffer replaceBytesInRange:NSMakeRange(0, bodyLength) withBytes:NULL length:0];

        [self setIsParsingHeader:YES];
    }
    //继续监听数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)processMessage:(TJPAdavancedHeader)header payload:(NSData *)payload {
    switch (ntohs(header.msgType)) {
        case TJPMessageTypeNormalData:
            [self handleDataMessage:header payload:payload];
            break;
        case TJPMessageTypeHeartbeat:
            [self handleHeartbeat];
            break;
        case TJPMessageTypeACK:
            [self handleACK:ntohl(header.sequence)];
            break;
    }
}



- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.isConnected = NO;
    //停止心跳
    [self stopHeartbeat];
    //准备重连
    [self scheduleReconnect];
}


#pragma mark - Private Method
- (void)setupNetworkReachability {
    _networkReachability = [Reachability reachabilityForInternetConnection];
    
    __weak typeof(self) weakSelf = self;
    _networkReachability.reachableBlock = ^(Reachability *reach) {
        if (!weakSelf.isConnected) {
            [weakSelf scheduleReconnect];
        }
    };
    
    [_networkReachability startNotifier];
}

- (void)startHeartbeat {
    [self stopHeartbeat];
    
    __weak typeof(self) weakSelf = self;
    self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_networkQueue);
    
    //从当前时间开始延迟15秒后开始第一次执行  DISPATCH_TIME_NOW->15 * NSEC_PER_SEC
    //周期:每15秒执行一次  15 * NSEC_PER_SEC
    //最小时间间隔:1秒  1 * NSEC_PER_SEC
    dispatch_source_set_timer(self.heartbeatTimer, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), 15 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(self.heartbeatTimer, ^{
        //发送心跳包
        [weakSelf sendHeartbeat];
        //更新上次心跳时间
        weakSelf.lastHeartbeatTime = [NSDate date];
        
        //超时心跳检查
        if ([[NSDate date] timeIntervalSinceDate:weakSelf.lastHeartbeatTime] > 30) {
            TJPLOG_WARN(@"心跳超时，主动断开连接");
            [weakSelf disconnectAndRetry];
        }
    });
    dispatch_resume(self.heartbeatTimer);
}

- (void)stopHeartbeat {
    if (self.heartbeatTimer) {
        dispatch_source_cancel(self.heartbeatTimer);
        self.heartbeatTimer = nil;
    }
}


- (void)sendHeartbeat {
    //心跳包双向检测机制
    TJPAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeHeartbeat);
    //携带序列号
    header.sequence = htonl(++_currentSequence);
    
    NSData *packet = [NSData dataWithBytes:&header length:sizeof(header)];
    [self.socket writeData:packet withTimeout:-1 tag:0];
    
    // 记录发出的心跳包
    self.pendingHeartbeats[@(_currentSequence)] = [NSDate date];
}



- (void)handleDataMessage:(TJPAdavancedHeader)header payload:(NSData *)payload {
    //校验数据完整性
    if ([self validateChecksum:header payload:payload]) {
        //分发业务层
        [self dispatchMessage:header payload:payload];
        
        //发送ack确认
        [self sendACKForSequence:ntohl(header.sequence)];
    }else {
        NSError *error = [TJPNETError errorWithCode:TJPNETErrorDataCorrupted
                                           userInfo:@{NSLocalizedDescriptionKey: @"数据校验失败"}];
        [TJPNETErrorHandler handleError:error inManager:self];
    }
}

- (void)dispatchMessage:(TJPAdavancedHeader)header payload:(NSData *)payload {
    uint16_t msgType = ntohs(header.msgType);
    switch (msgType) {
        case TJPMessageTypeNormalData:
            TJPLOG_INFO(@"收到正常消息");
            //TODO 准备分发给业务层
            break;
            
        case TJPMessageTypeHeartbeat:
            TJPLOG_INFO(@"收到心跳响应");
            break;

        case TJPMessageTypeACK:
            TJPLOG_INFO(@"收到 ACK 确认, 序列号: %u", ntohl(header.sequence));
            break;

        default:
            TJPLOG_WARN(@"收到未知类型消息: %u", msgType);
            break;
    }
}


#pragma mark - Thread Safe Method
- (void)setIsParsingHeaderSafe:(BOOL)value {
    dispatch_async(self->_networkQueue, ^{
        self->_isParsingHeader = value;
    });
}

- (BOOL)isParsingHeaderSafe {
    __block BOOL result;
    dispatch_sync(self->_networkQueue, ^{
        result = self->_isParsingHeader;
    });
    return result;
}

- (void)addPendingMessage:(NSData *)data forSequence:(NSUInteger)sequence {
    dispatch_async(self->_networkQueue, ^{
        self.pendingMessages[@(sequence)] = data;
    });
}

- (void)removePendingMessageForSequence:(NSUInteger)sequence {
    dispatch_async(self->_networkQueue, ^{
        [self.pendingMessages removeObjectForKey:@(sequence)];
    });
}

- (void)checkPendingMessageTimeoutForSequence:(NSUInteger)sequence {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), self->_networkQueue, ^{
        if (self.pendingMessages[@(sequence)]) {
            TJPLOG_WARN(@"消息 %lu 超时未确认", sequence);
            [self resendPacket:sequence];
        }
    });
}

//ack确认
- (void)sendACKForSequence:(uint32_t)sequence {
    dispatch_async(self->_networkQueue, ^{
        TJPAdavancedHeader ackHeader = {0};
        ackHeader.magic = htonl(kProtocolMagic);
        ackHeader.msgType = htons(TJPMessageTypeACK);
        ackHeader.sequence = htonl(sequence);

        NSData *packet = [NSData dataWithBytes:&ackHeader length:sizeof(ackHeader)];
        
        if (self.isConnected) {
            [self.socket writeData:packet withTimeout:-1 tag:sequence];
        } else {
            TJPLOG_WARN(@"连接断开，ACK 发送失败");
        }
    });
}

- (BOOL)validateChecksum:(TJPAdavancedHeader)header payload:(NSData *)payload {
    uint32_t receivedChecksum = ntohl(header.checksum);
    uint32_t calculatedChecksum = [self _crc32ForData:payload];
    return receivedChecksum == calculatedChecksum;
}

- (void)handleHeartbeat {
    _lastHeartbeatTime = [NSDate date];
}

- (void)handleACK:(uint32_t)sequence {
    TJPLOG_INFO(@"收到 %u 的ACK", sequence);
    [self removePendingMessageForSequence:sequence];
}


- (void)handleInvalidData {
    //魔数校验失败
    NSError *error = [TJPNETError errorWithCode:TJPNETErrorInvalidProtocol
                                      userInfo:@{NSLocalizedDescriptionKey: @"魔数校验失败"}];
    [TJPNETErrorHandler handleError:error inManager:self];
    
    TJPLOG_ERROR(@"魔数校验失败，正在重置连接...");
    
    //重置连接
    [self resetConnection];
}

- (void)resetParse {
    [self.parseBuffer setLength:0];
    _currentHeader = (TJPAdavancedHeader){0};
}


- (void)disconnectAndRetry {
    [self disconnect];
    [self scheduleReconnect];
}

- (void)resendPacket:(NSUInteger)sequence {
    NSData *data = self.pendingMessages[@(sequence)];
    if (data) {
        TJPLOG_INFO(@"重发消息 %lu", sequence);
        NSData *packet = [self _buildPacketWithType:TJPMessageTypeNormalData data:data];
        [self.socket writeData:packet withTimeout:-1 tag:sequence];
    }
}


- (NSData *)_buildPacketWithType:(TJPMessageType)msgType data:(NSData *)msgData {
    //初始化协议头
    TJPAdavancedHeader header;
    //清空内存 避免不必要错误
    memset(&header, 0, sizeof(header));
    //字段填充
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(msgType);
    header.sequence = htonl(++_currentSequence);
    header.bodyLength = htonl((uint32_t)msgData.length);
    header.checksum = [self _crc32ForData:msgData];
    
    NSMutableData *packet = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [packet appendData:msgData];
    return packet;
}


- (void)disconnect {
    [_socket disconnect];
    _socket = nil;
    [self stopHeartbeat];
}

- (uint32_t)_crc32ForData:(NSData *)data {
    uLong crc = crc32(0L, Z_NULL, 0);
    crc = crc32(crc, [data bytes], (uInt)[data length]);
    return (uint32_t)crc;
}



- (void)handleError:(NSError *)error {
    TJPLOG_ERROR(@"网络错误: %@", error);
    if ([error.domain isEqualToString:GCDAsyncSocketErrorDomain]) {
        [self scheduleReconnect];
    }
}


- (void)postNotification:(NSString *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:notification object:nil];
    });
}



#pragma mark - Lazy
- (NSMutableDictionary<NSNumber *,NSData *> *)pendingMessages {
    if (!_pendingMessages) {
        _pendingMessages = [NSMutableDictionary dictionary];
    }
    return _pendingMessages;
}

- (NSMutableDictionary<NSNumber *,NSDate *> *)pendingHeartbeats {
    if (!_pendingHeartbeats) {
        _pendingHeartbeats = [NSMutableDictionary dictionary];
    }
    return _pendingHeartbeats;
}

- (NSMutableData *)parseBuffer {
    if (!_parseBuffer) {
        _parseBuffer = [NSMutableData data];
    }
    return _parseBuffer;
}
@end
