//
//  TJPMessageParser.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageParser.h"
#import "TJPNetworkDefine.h"
#import "TJPParsedPacket.h"
#import "TJPCoreTypes.h"
#import "TJPNetworkUtil.h"
#import "TJPErrorUtil.h"
#import "TJPRingBuffer.h"



@interface TJPMessageParser () {
    // 协议解析状态
    TJPFinalAdavancedHeader _currentHeader;
    TJPParseState _state;
    
    // 双缓冲区实现 - 通过开关控制
    NSMutableData *_traditionBuffer;       // 旧实现：NSMutableData
    TJPRingBuffer *_ringBuffer;            // 新实现：环形缓冲区
    BOOL _isUseRingBuffer;                 // 实现切换开关
    TJPBufferStrategy _strategy;           // 用户设置的策略
    NSUInteger _requestCapacity;           // 用户请求的容量
    
    // 安全相关
    NSMutableSet *_recentSequences;  //防重放攻击
    NSDate *_lastCleanupTime;  //定期清理计数器
    
    // 简单的错误统计
    NSUInteger _errorCount;
    NSUInteger _totalOperations;
    NSUInteger _switchCount;               // 切换次数统计
    
    
    // 增加性能统计
    CFTimeInterval _totalParseTime;        // 总解析时间
    NSUInteger _totalPacketCount;          // 总包数量
    CFTimeInterval _lastBenchmarkTime;     // 上次基准测试时间
}

@end

@implementation TJPMessageParser
#pragma mark - Lifecycle
- (instancetype)init {
    return [self initWithBufferStrategy:TJPBufferStrategyAuto];
}

- (instancetype)initWithRingBufferEnabled:(BOOL)enabled {
    TJPBufferStrategy strategy = enabled ? TJPBufferStrategyRingBuffer : TJPBufferStrategyTradition;
    return [self initWithBufferStrategy:strategy];
}

- (instancetype)initWithBufferStrategy:(TJPBufferStrategy)strategy {
    NSUInteger defaultCapacity = [self class].recommendedDefaultCapacity;
    return [self initWithBufferStrategy:strategy capacity:defaultCapacity];

}

- (instancetype)initWithBufferStrategy:(TJPBufferStrategy)strategy capacity:(NSUInteger)capacity {
    if (self = [super init]) {
        _state = TJPParseStateHeader;
        _strategy = strategy;
        _requestCapacity = capacity;
        _errorCount = 0;
        _totalOperations = 0;
        _switchCount = 0;
        
        // 安全相关初始化
        _recentSequences = [NSMutableSet setWithCapacity:1000];
        _lastCleanupTime = [NSDate date];
        
        // 初始化缓冲区
        [self setupBuffersWithStrategy:strategy capacity:capacity];

        // 性能统计初始化
        _totalParseTime = 0;
        _totalPacketCount = 0;
        _lastBenchmarkTime = CFAbsoluteTimeGetCurrent();
        
        TJPLOG_INFO(@"MessageParser 初始化完成，使用%@缓冲区", _isUseRingBuffer ? @"环形" : @"传统");
    }
    return self;
}

- (void)setupBuffersWithStrategy:(TJPBufferStrategy)strategy capacity:(NSUInteger)capacity {
    _traditionBuffer = [NSMutableData data];
    
    switch (strategy) {
        case TJPBufferStrategyTradition:
            _isUseRingBuffer = NO;
            _ringBuffer = nil;
            break;
            
        case TJPBufferStrategyRingBuffer:
            _isUseRingBuffer = [self setupRingBufferWithCapacity:capacity];
            break;
            
        case TJPBufferStrategyAuto:
        default:
            _isUseRingBuffer = [self autoSetupWithCapacity:capacity];
            break;
    }
}

- (BOOL)setupRingBufferWithCapacity:(NSUInteger)capacity {
    // 检查容量合理性
    capacity = [self validateCapacity:capacity];
    
    _ringBuffer = [[TJPRingBuffer alloc] initWithCapacity:capacity];
    if (!_ringBuffer) {
        TJPLOG_ERROR(@"环形缓冲区初始化失败，容量: %luKB", (unsigned long)capacity / 1024);
        [self recordError:@"环形缓冲区初始化失败"];
        return NO;
    }
    
    return YES;
    
    
    
}

- (BOOL)autoSetupWithCapacity:(NSUInteger)capacity {
    if (self.strategyDelegate && [self.strategyDelegate respondsToSelector:@selector(shouldUserRingBufferForParser:)]) {
        BOOL shouldUse = [_strategyDelegate shouldUserRingBufferForParser:self];
        if (!shouldUse) {
            TJPLOG_INFO(@"策略代理建议使用传统缓冲区");
            return NO;
        }
    }
    
    // 简单抉择逻辑 后续可以扩展为更完善逻辑
    if ([self shouldUseRingBufferByDefault]) {
        return [self setupRingBufferWithCapacity:capacity];
    }else {
        TJPLOG_INFO(@"自动选择传统缓冲区");
        return NO;
    }
}


#pragma mark - Public Method
- (void)feedData:(NSData *)data {
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();

    if (!data || data.length == 0) {
        return;
    }
    
    _totalOperations++;

    // 防止缓冲区过大导致内存耗尽
    if (data.length > TJPMAX_BUFFER_SIZE ) {
        TJPLOG_ERROR(@"数据大小超过限制: %lu > %d", (unsigned long)data.length, TJPMAX_BUFFER_SIZE);
        [self reset];
        _state = TJPParseStateError;
        [self recordError:@"数据大小超限"];
        return;
    }
    
    // 根据开关选择实现
    if (_isUseRingBuffer) {
        [self feedDataWithRingBuffer:data];
    } else {
        [self feedDataWithLegacyBuffer:data];
    }
    
    //定期清理过期序列号
    [self cleanupExpiredSequences];
    
    _totalParseTime += (CFAbsoluteTimeGetCurrent() - startTime);

}

- (BOOL)hasCompletePacket {
    if (_state == TJPParseStateError) {
        return NO;
    }
    
    if (_isUseRingBuffer) {
        return [self hasCompletePacketWithRingBuffer];
    } else {
        return [self hasCompletePacketWithLegacyBuffer];
    }
}

- (TJPParsedPacket *)nextPacket {
    // 错误状态下不处理
    if (_state == TJPParseStateError) {
        TJPLOG_ERROR(@"解析器处于错误状态，请先重置");
        return nil;
    }
    
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();
    
    TJPParsedPacket *result = nil;
    if (_isUseRingBuffer) {
        result = [self nextPacketWithRingBuffer];
    } else {
        result = [self nextPacketWithLegacyBuffer];
    }
    
    // 性能统计
    if (result) {
        _totalPacketCount++;
        _totalParseTime += (CFAbsoluteTimeGetCurrent() - startTime);
    }

    return result;
}

- (void)reset {
    [_traditionBuffer setLength:0];
    [_ringBuffer reset];
    _currentHeader = (TJPFinalAdavancedHeader){0};
    _state = TJPParseStateHeader;
    
    TJPLOG_INFO(@"MessageParser 重置完成");
}

#pragma mark - Ring Buffer
- (void)feedDataWithRingBuffer:(NSData *)data {
    @try {
        // 检查剩余空间
        if (_ringBuffer.availableSpace < data.length) {
            TJPLOG_ERROR(@"环形缓冲区空间不足: 需要 %lu, 可用 %lu",
                         (unsigned long)data.length, (unsigned long)_ringBuffer.availableSpace);
            [self reset];
            _state = TJPParseStateError;
            return;
        }
        
        NSUInteger written = [_ringBuffer writeData:data];
        if (written != data.length) {
            TJPLOG_ERROR(@"环形缓冲区写入不完整: 期望 %lu, 实际 %lu",
                         (unsigned long)data.length, (unsigned long)written);
            _state = TJPParseStateError;
            return;
        }
        
    } @catch (NSException *exception) {
        TJPLOG_ERROR(@"环形缓冲区异常: %@", exception.reason);
        [self handleRingBufferError:exception.reason];
        
    }
    
    //    TJPLOG_INFO(@"[环形Buffer] 收到数据: %lu 字节, 缓冲区使用率: %.1f%%",
    //                (unsigned long)data.length, _ringBuffer.usageRatio * 100);
}

- (BOOL)hasCompletePacketWithRingBuffer {
    if (_state == TJPParseStateHeader) {
        return [_ringBuffer hasAvailableData:sizeof(TJPFinalAdavancedHeader)];
    } else if (_state == TJPParseStateBody) {
        uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
        return [_ringBuffer hasAvailableData:bodyLength];
    }
    return NO;
}

- (TJPParsedPacket *)nextPacketWithRingBuffer {
    // 解析头部
    if (_state == TJPParseStateHeader) {
        if (![self parseHeaderWithRingBuffer]) {
            return nil;
        }
    }
    
    // 解析消息体
    if (_state == TJPParseStateBody) {
        return [self parseBodyWithRingBuffer];
    }
    
    return nil;
}

- (BOOL)parseHeaderWithRingBuffer {
    if (![_ringBuffer hasAvailableData:sizeof(TJPFinalAdavancedHeader)]) {
        TJPLOG_WARN(@"环形缓冲区数据不足，无法解析头部");
        return NO;
    }
    
    // 从环形缓冲区读取头部数据
    TJPFinalAdavancedHeader header = {0};
    NSUInteger readBytes = [_ringBuffer readBytes:&header length:sizeof(TJPFinalAdavancedHeader)];
    
    if (readBytes != sizeof(TJPFinalAdavancedHeader)) {
        TJPLOG_ERROR(@"头部数据读取不完整: 期望 %lu, 实际 %lu",
                    (unsigned long)sizeof(TJPFinalAdavancedHeader), (unsigned long)readBytes);
        _state = TJPParseStateError;
        return NO;
    }
    
    // 头部验证
    NSError *validationError = nil;
    if (![self validateHeader:header error:&validationError]) {
        TJPLOG_ERROR(@"头部验证失败: %@", validationError.localizedDescription);
        _state = TJPParseStateError;
        return NO;
    }
    
    _currentHeader = header;
    _state = TJPParseStateBody;
    
//    TJPLOG_INFO(@"[环形Buffer] 解析序列号:%u 的头部成功", ntohl(_currentHeader.sequence));
    return YES;
}

- (TJPParsedPacket *)parseBodyWithRingBuffer {
    uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
    
    if (![_ringBuffer hasAvailableData:bodyLength]) {
        TJPLOG_INFO(@"环形缓冲区数据不足，等待更多数据...");
        return nil;
    }
    
    // 读取消息体数据
    NSData *payload = [_ringBuffer readData:bodyLength];
    if (!payload || payload.length != bodyLength) {
        TJPLOG_ERROR(@"消息体数据读取失败: 期望 %u, 实际 %lu",
                    bodyLength, (unsigned long)payload.length);
        _state = TJPParseStateError;
        return nil;
    }
    
    // 验证校验和
    if (![self validateChecksum:_currentHeader.checksum forData:payload]) {
        TJPLOG_ERROR(@"校验和验证失败，可能数据已被篡改");
        _state = TJPParseStateError;
        return nil;
    }
    
    // 创建解析结果
    NSError *error = nil;
    TJPParsedPacket *packet = [TJPParsedPacket packetWithHeader:_currentHeader
                                                        payload:payload
                                                         policy:TJPTLVTagPolicyRejectDuplicates
                                                 maxNestedDepth:4
                                                          error:&error];
    if (error) {
        TJPLOG_ERROR(@"[环形Buffer] 解析序列号:%u 的内容失败: %@",
                    ntohl(_currentHeader.sequence), error.localizedDescription);
        _state = TJPParseStateError;
        return nil;
    }
    
//    TJPLOG_INFO(@"[环形Buffer] 解析序列号:%u 的内容成功", ntohl(_currentHeader.sequence));
    _state = TJPParseStateHeader;
    return packet;
}

#pragma mark Tradition Buffer
- (void)feedDataWithLegacyBuffer:(NSData *)data {
    @synchronized (self) {
        if ((_traditionBuffer.length + data.length) > TJPMAX_BUFFER_SIZE) {
            TJPLOG_ERROR(@"传统缓冲区大小超过限制: 当前 %lu, 新增 %lu, 限制 %d",
                         (unsigned long)_traditionBuffer.length, (unsigned long)data.length, TJPMAX_BUFFER_SIZE);
            [self reset];
            _state = TJPParseStateError;
            [self recordError:@"缓冲区超限"];
            return;
        }
        
        [_traditionBuffer appendData:data];
    }
    
    //    TJPLOG_INFO(@"[传统Buffer] 收到数据: %lu 字节", (unsigned long)data.length);
}

- (BOOL)hasCompletePacketWithLegacyBuffer {
    if (_state == TJPParseStateHeader) {
        return _traditionBuffer.length >= sizeof(TJPFinalAdavancedHeader);
    } else if (_state == TJPParseStateBody) {
        uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
        return _traditionBuffer.length >= bodyLength;
    }
    return NO;
}

- (TJPParsedPacket *)nextPacketWithLegacyBuffer {
    // 解析头部
    if (_state == TJPParseStateHeader) {
        if (![self parseHeaderWithLegacyBuffer]) {
            return nil;
        }
    }
    
    // 解析消息体
    if (_state == TJPParseStateBody) {
        return [self parseBodyWithLegacyBuffer];
    }
    
    return nil;
}

- (BOOL)parseHeaderWithLegacyBuffer {
    if (_traditionBuffer.length < sizeof(TJPFinalAdavancedHeader)) {
        TJPLOG_INFO(@"数据长度不够数据头解析");
        return NO;
    }
    TJPFinalAdavancedHeader currentHeader = {0};

    // 解析头部
    [_traditionBuffer getBytes:&currentHeader length:sizeof(TJPFinalAdavancedHeader)];
    
    // 安全验证
    NSError *validationError = nil;
    if (![self validateHeader:currentHeader error:&validationError]) {
        TJPLOG_ERROR(@"头部验证失败: %@", validationError.localizedDescription);
        _state = TJPParseStateError;
        return NO;
    }
    
    TJPLOG_INFO(@"解析数据头部成功...魔数校验成功!");
    _currentHeader = currentHeader;
    // 移除已处理的Header数据
    [_traditionBuffer replaceBytesInRange:NSMakeRange(0, sizeof(TJPFinalAdavancedHeader)) withBytes:NULL length:0];
    
//    TJPLOG_INFO(@"解析序列号:%u 的头部成功", ntohl(_currentHeader.sequence));
    _state = TJPParseStateBody;
    
    return YES;
}

- (TJPParsedPacket *)parseBodyWithLegacyBuffer {
    uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
    if (_traditionBuffer.length < bodyLength) {
        TJPLOG_INFO(@"数据长度不够内容解析,等待更多数据...");
        return nil;
    }
    
    NSData *payload = [_traditionBuffer subdataWithRange:NSMakeRange(0, bodyLength)];
    [_traditionBuffer replaceBytesInRange:NSMakeRange(0, bodyLength) withBytes:NULL length:0];
    
    // 验证CRC32校验和
    if (![self validateChecksum:_currentHeader.checksum forData:payload]) {
        TJPLOG_ERROR(@"校验和验证失败，可能数据已被篡改");
        _state = TJPParseStateError;
        return nil;
    }
    
    NSError *error = nil;
    TJPParsedPacket *body = [TJPParsedPacket packetWithHeader:_currentHeader payload:payload policy:TJPTLVTagPolicyRejectDuplicates maxNestedDepth:4 error:&error];
    if (error) {
        TJPLOG_INFO(@"解析序列号:%u 的内容失败: %@", ntohl(_currentHeader.sequence), error.localizedDescription);
        _state = TJPParseStateError;
        return nil;
    }
    
//    TJPLOG_INFO(@"解析序列号:%u 的内容成功", ntohl(_currentHeader.sequence));

    _state = TJPParseStateHeader;
    return body;
}

- (BOOL)validateChecksum:(uint32_t)expectedChecksum forData:(NSData *)data {
    uint32_t calculatedChecksum = [TJPNetworkUtil crc32ForData:data];
    
    if (calculatedChecksum != expectedChecksum) {
        TJPLOG_ERROR(@"校验和不匹配: 期望 %u, 计算得到 %u", expectedChecksum, calculatedChecksum);
        return NO;
    }
    
    return YES;
}


#pragma mark - Private Method
- (BOOL)validateHeader:(TJPFinalAdavancedHeader)header error:(NSError **)error {
    //魔数校验
    if (ntohl(header.magic) != kProtocolMagic) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorProtocolMagicInvalid
                                    description:@"无效的魔数"
                                      userInfo:@{@"receivedMagic": @(ntohl(header.magic)),
                                                @"expectedMagic": @(kProtocolMagic)}];
        }
        TJPLOG_ERROR(@"魔数校验失败: 0x%X != 0x%X", ntohl(header.magic), kProtocolMagic);
        return NO;
    }
    
    //版本校验
    if (header.version_major != kProtocolVersionMajor || header.version_minor > kProtocolVersionMinor) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorProtocolVersionMismatch
                                    description:@"不支持的协议版本"
                                      userInfo:@{@"receivedVersion": [NSString stringWithFormat:@"%d.%d",
                                                                    header.version_major,
                                                                    header.version_minor],
                                                @"supportedVersion": [NSString stringWithFormat:@"%d.%d",
                                                                    kProtocolVersionMajor,
                                                                    kProtocolVersionMinor]}];
        }
        TJPLOG_ERROR(@"协议版本不支持: %d.%d (当前支持: %d.%d)",
                   header.version_major, header.version_minor,
                   kProtocolVersionMajor, kProtocolVersionMinor);
        return NO;
    }
    
    //消息体长度校验
    uint32_t bodyLength = ntohl(header.bodyLength);
    if (bodyLength > TJPMAX_BODY_SIZE) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorMessageTooLarge
                                    description:@"消息体长度超过限制"
                                      userInfo:@{@"bodyLength": @(bodyLength),
                                                @"maxSize": @(TJPMAX_BODY_SIZE)}];
        }
        TJPLOG_ERROR(@"消息体长度超过限制: %u > %d", bodyLength, TJPMAX_BODY_SIZE);
        return NO;
    }
    
    //时间戳校验
    uint32_t currTime = (uint32_t)[[NSDate date] timeIntervalSince1970];
    uint32_t timestamp = ntohl(header.timestamp); // 确保字节序转换
    int32_t timeDiff = (int32_t)currTime - (int32_t)timestamp;

    if (abs(timeDiff) > TJPMAX_TIME_WINDOW) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorProtocolTimestampInvalid
                                    description:@"时间戳超出有效窗口"
                                      userInfo:@{@"currentTime": @(currTime),
                                                @"messageTime": @(timestamp),
                                                @"difference": @(timeDiff)}];
        }
        TJPLOG_ERROR(@"时间戳超出有效窗口: 当前时间 %u, 消息时间 %u, 差值 %d秒",
                   currTime, timestamp, timeDiff);
        return NO;
    }
    
    //序列号防重放检查
    uint32_t sequence = ntohl(header.sequence);
    NSString *uniqueID = [NSString stringWithFormat:@"%u-%u", sequence, timestamp];
    
    @synchronized (_recentSequences) {
        if ([_recentSequences containsObject:uniqueID]) {
            if (error) {
                *error = [TJPErrorUtil errorWithCode:TJPErrorSecurityReplayAttackDetected
                                         description:@"检测到重放攻击"
                                            userInfo:@{@"sequence": @(sequence),
                                                       @"timestamp": @(timestamp)}];
            }
            TJPLOG_ERROR(@"检测到重放攻击: 序列号 %u, 时间戳 %u", sequence, timestamp);
            return NO;
        }
        [_recentSequences addObject:uniqueID];
    }
    
    // 校验加密类型和压缩类型
    if (![self isSupportedEncryptType:header.encrypt_type]) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorProtocolUnsupportedEncryption
                                    description:@"不支持的加密类型"
                                      userInfo:@{@"encryptType": @(header.encrypt_type)}];
        }
        TJPLOG_ERROR(@"不支持的加密类型: %d", header.encrypt_type);
        return NO;
    }
    
    if (![self isSupportedCompressType:header.compress_type]) {
        if (error) {
            *error = [TJPErrorUtil errorWithCode:TJPErrorProtocolUnsupportedCompression
                                    description:@"不支持的压缩类型"
                                      userInfo:@{@"compressType": @(header.compress_type)}];
        }
        TJPLOG_ERROR(@"不支持的压缩类型: %d", header.compress_type);
        return NO;
    }
    
    return YES;
}

- (BOOL)isSupportedEncryptType:(TJPEncryptType)type {
    // 根据实际支持的加密类型进行验证
    switch (type) {
        case TJPEncryptTypeNone:
        case TJPEncryptTypeCRC32:
        case TJPEncryptTypeAES256:
            return YES;
        default:
            return NO;
    }
}

- (BOOL)isSupportedCompressType:(TJPCompressType)type {
    // 根据实际支持的压缩类型进行验证
    switch (type) {
        case TJPCompressTypeNone:
        case TJPCompressTypeZlib:
//        case TJPCompressTypeLZ4:
            return YES;
        default:
            return NO;
    }
}

- (void)cleanupExpiredSequences {
    NSDate *now = [NSDate date];
    NSTimeInterval elapsed = [now timeIntervalSinceDate:_lastCleanupTime];
    
    // 每分钟清理一次
    if (elapsed > 60) {
        @synchronized (_recentSequences) {
            // 过期的序列号集合会随着时间增加而增长，定期清理
            TJPLOG_INFO(@"清理过期序列号缓存，当前数量: %lu", (unsigned long)_recentSequences.count);
            [_recentSequences removeAllObjects];
            _lastCleanupTime = now;
        }
    }
}


- (BOOL)shouldUseRingBufferByDefault {
    // 内存检查
    NSUInteger totalMemoryMB = [NSProcessInfo processInfo].physicalMemory / (1024 * 1024);
    
    if (totalMemoryMB < 1024) {
        TJPLOG_INFO(@"设备内存较少(%luMB)，选择传统缓冲区", (unsigned long)totalMemoryMB);
        return NO;
    }
    
    // 历史错误率检查（简单版本）
    if (_totalOperations > 100 && (CGFloat)_errorCount / _totalOperations > 0.1) {
        TJPLOG_INFO(@"历史错误率较高(%.1f%%)，选择传统缓冲区",
                   (CGFloat)_errorCount / _totalOperations * 100);
        return NO;
    }

    // 默认倾向于使用环形缓冲区
    return YES;
    
}


- (NSUInteger)validateCapacity:(NSUInteger)capacity {
    if (self.strategyDelegate && [self.strategyDelegate respondsToSelector:@selector(recommendedCapacityForParser:)]) {
        NSUInteger delegateCapacity = [self.strategyDelegate recommendedCapacityForParser:self];
        if (delegateCapacity > 0) {
            capacity = delegateCapacity;
        }
    }
    
    // 边界检查
    NSUInteger minCapacity = 16 * 1024;  //最小16KB
    NSUInteger maxCapacity = 1024 * 1024; //最大1MB
    
    if (capacity < minCapacity) {
        TJPLOG_WARN(@"容量过小(%luKB)，调整为最小值%luKB",
                    (unsigned long)capacity / 1024, (unsigned long)minCapacity / 1024);
        capacity = minCapacity;
    } else if (capacity > maxCapacity) {
        TJPLOG_WARN(@"容量过大(%luKB)，调整为最大值%luKB",
                    (unsigned long)capacity / 1024, (unsigned long)maxCapacity / 1024);
        capacity = maxCapacity;
    }
    
    return capacity;
    
}


+ (NSUInteger)recommendedDefaultCapacity {
    NSUInteger totalMemoryMB = [NSProcessInfo processInfo].physicalMemory / (1024 * 1024);
    
    if (totalMemoryMB < 1024) {
        return 16 * 1024;   // 16KB - 低端设备
    } else if (totalMemoryMB < 2048) {
        return 32 * 1024;   // 32KB - 中端设备
    } else if (totalMemoryMB < 4096) {
        return 64 * 1024;   // 64KB - 高端设备
    } else {
        return 128 * 1024;  // 128KB - 顶级设备
    }
}


- (NSString *)strategyDescription:(TJPBufferStrategy)strategy {
    switch (strategy) {
        case TJPBufferStrategyAuto: return @"自动选择";
        case TJPBufferStrategyTradition: return @"强制传统";
        case TJPBufferStrategyRingBuffer: return @"强制环形";
        default: return @"未知策略";
    }
}

- (NSString *)stateDescription:(TJPParseState)state {
    switch (state) {
        case TJPParseStateHeader: return @"等待头部";
        case TJPParseStateBody: return @"等待消息体";
        case TJPParseStateError: return @"错误状态";
        default: return @"未知状态";
    }
}

#pragma mark - Method Change
- (BOOL)switchToRingBuffer {
    return [self switchToRingBufferWithCapacity:_requestCapacity];
}

- (BOOL)switchToRingBufferWithCapacity:(NSUInteger)capacity {
    if (_isUseRingBuffer) {
        TJPLOG_INFO(@"已经在使用环形缓冲区");
        return YES;
    }
    
    // 创建新的环形缓冲区
    capacity = [self validateCapacity:capacity];
    TJPRingBuffer *newRingBuffer = [[TJPRingBuffer alloc] initWithCapacity:capacity];
    
    if (!newRingBuffer) {
        TJPLOG_ERROR(@"环形缓冲区创建失败");
        [self recordError:@"环形缓冲区创建失败"];
        return NO;
    }
    
    // 数据迁移
    if (_traditionBuffer.length > 0) {
        NSUInteger written = [newRingBuffer writeData:_traditionBuffer];
        if (written != _traditionBuffer.length) {
            TJPLOG_WARN(@"数据迁移不完整: %lu/%lu",
                       (unsigned long)written, (unsigned long)_traditionBuffer.length);
        }
        TJPLOG_INFO(@"成功迁移 %lu 字节数据到环形缓冲区", (unsigned long)written);
    }
    
    // 切换实现
    _ringBuffer = newRingBuffer;
    [_traditionBuffer setLength:0];
    _isUseRingBuffer = YES;
    _switchCount++;
    
    TJPLOG_INFO(@"成功切换到环形缓冲区，容量: %luKB", (unsigned long)capacity / 1024);
    
    // 通知代理
    [self notifyStrategySwitch:@"环形缓冲区" reason:@"手动切换"];
    
    return YES;
}

- (void)switchToTraditionBuffer {
    if (!_isUseRingBuffer) {
        TJPLOG_INFO(@"已经在使用传统缓冲区");
        return;
    }
    
    // 数据迁移
    if (_ringBuffer.usedSize > 0) {
        NSData *data = [_ringBuffer readData:_ringBuffer.usedSize];
        if (data) {
            [_traditionBuffer appendData:data];
            TJPLOG_INFO(@"成功迁移 %lu 字节数据到传统缓冲区", (unsigned long)data.length);
        }
    }
    
    // 切换实现
    _isUseRingBuffer = NO;
    _switchCount++;
    
    TJPLOG_INFO(@"成功切换到传统缓冲区");
    
    // 通知代理
    [self notifyStrategySwitch:@"传统缓冲区" reason:@"手动切换"];
}

- (BOOL)switchToOptimalMode {
    BOOL shouldUseRing = [self shouldUseRingBufferByDefault];
    
    if (shouldUseRing && !_isUseRingBuffer) {
        return [self switchToRingBuffer];
    } else if (!shouldUseRing && _isUseRingBuffer) {
        [self switchToTraditionBuffer];
        return YES;
    }
    
    TJPLOG_INFO(@"当前模式已是最优模式");
    return YES;
}

- (void)handleRingBufferError:(NSString *)reason {
    [self recordError:reason];
    
    // 咨询策略代理
    if ([_strategyDelegate respondsToSelector:@selector(parser:shouldContinueAfterError:)]) {
        NSError *error = [NSError errorWithDomain:@"TJPRingBufferError"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
        BOOL shouldContinue = [_strategyDelegate parser:self shouldContinueAfterError:error];
        if (!shouldContinue) {
            TJPLOG_WARN(@"策略代理建议切换实现，原因: %@", reason);
            [self switchToTraditionBuffer];
            return;
        }
    }
    
    // 简单的错误处理策略
    if (_errorCount > 5 && _totalOperations > 10) {
        CGFloat errorRate = (CGFloat)_errorCount / _totalOperations;
        if (errorRate > 0.3) { // 错误率超过30%
            TJPLOG_WARN(@"环形缓冲区错误率过高(%.1f%%)，切换到传统模式", errorRate * 100);
            [self switchToTraditionBuffer];
            return;
        }
    }
    
    // 继续使用环形缓冲区，但重置状态
    [self reset];
    _state = TJPParseStateError;
}

- (void)recordError:(NSString *)reason {
    _errorCount++;
    TJPLOG_ERROR(@"记录错误: %@ (总错误: %lu, 总操作: %lu)",
                reason, (unsigned long)_errorCount, (unsigned long)_totalOperations);
}

- (void)notifyStrategySwitch:(NSString *)implementation reason:(NSString *)reason {
    if ([_strategyDelegate respondsToSelector:@selector(parser:didSwitchToImplementation:reason:)]) {
        [_strategyDelegate parser:self didSwitchToImplementation:implementation reason:reason];
    }
}


#pragma mark - 属性实现
- (BOOL)isUsingRingBuffer {
    return _isUseRingBuffer;
}

- (NSUInteger)bufferCapacity {
    if (_isUseRingBuffer) {
        return _ringBuffer.capacity;
    } else {
        return TJPMAX_BUFFER_SIZE; // 传统缓冲区的理论最大容量
    }
}

- (NSUInteger)usedBufferSize {
    if (_isUseRingBuffer) {
        return _ringBuffer.usedSize;
    } else {
        return _traditionBuffer.length;
    }
}

- (CGFloat)bufferUsageRatio {
    if (_isUseRingBuffer) {
        return _ringBuffer.usageRatio;
    } else {
        return (CGFloat)_traditionBuffer.length / TJPMAX_BUFFER_SIZE;
    }
}

- (TJPBufferStrategy)currentStrategy {
    return _strategy;
}

- (TJPParseState)currentState {
    return _state;
}

- (NSMutableData *)buffer {
    if (_isUseRingBuffer) {
        NSUInteger usedSize = _ringBuffer.usedSize;
        if (usedSize > 0) {
            NSMutableData *testBuffer = [NSMutableData dataWithCapacity:usedSize];
            char *tempBuffer = malloc(usedSize);
            if (tempBuffer) {
                NSUInteger peeked = [_ringBuffer peekBytes:tempBuffer length:usedSize];
                if (peeked == usedSize) {
                    [testBuffer appendBytes:tempBuffer length:usedSize];
                }
                free(tempBuffer);
            }
            return testBuffer;
        }
        return [NSMutableData data];
    } else {
        return _traditionBuffer;
    }
}


- (TJPFinalAdavancedHeader)currentHeader {
    return _currentHeader;
}

#pragma mark - 监控和调试方法

- (void)printBufferStatus {
    TJPLOG_INFO(@"=== MessageParser 缓冲区状态 ===");
    TJPLOG_INFO(@"当前策略: %@", [self strategyDescription:_strategy]);
    TJPLOG_INFO(@"当前实现: %@", _isUseRingBuffer ? @"环形缓冲区" : @"传统缓冲区");
    TJPLOG_INFO(@"缓冲区容量: %luKB", (unsigned long)self.bufferCapacity / 1024);
    TJPLOG_INFO(@"已使用大小: %luKB", (unsigned long)self.usedBufferSize / 1024);
    TJPLOG_INFO(@"使用率: %.1f%%", self.bufferUsageRatio * 100);
    TJPLOG_INFO(@"解析状态: %@", [self stateDescription:_state]);
    TJPLOG_INFO(@"错误统计: %lu/%lu (%.2f%%)",
               (unsigned long)_errorCount, (unsigned long)_totalOperations,
               _totalOperations > 0 ? (CGFloat)_errorCount / _totalOperations * 100 : 0);
    TJPLOG_INFO(@"切换次数: %lu", (unsigned long)_switchCount);
}

- (NSDictionary *)bufferStatistics {
    return @{
        @"strategy": [self strategyDescription:_strategy],
        @"implementation": _isUseRingBuffer ? @"ring_buffer" : @"legacy",
        @"capacity": @(self.bufferCapacity),
        @"usedSize": @(self.usedBufferSize),
        @"usageRatio": @(self.bufferUsageRatio),
        @"state": [self stateDescription:_state],
        @"errorCount": @(_errorCount),
        @"totalOperations": @(_totalOperations),
        @"errorRate": @(_totalOperations > 0 ? (CGFloat)_errorCount / _totalOperations : 0),
        @"switchCount": @(_switchCount)
    };
}

@end



