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
    NSMutableData *_buffer;                // 旧实现：NSMutableData
    TJPRingBuffer *_ringBuffer;            // 新实现：环形缓冲区
    BOOL _useRingBuffer;                   // 实现切换开关
    
    // 安全相关
    NSMutableSet *_recentSequences;  //防重放攻击
    NSDate *_lastCleanupTime;  //定期清理计数器
    
    
    // 增加性能统计
    CFTimeInterval _totalParseTime;        // 总解析时间
    NSUInteger _totalPacketCount;          // 总包数量
    CFTimeInterval _lastBenchmarkTime;     // 上次基准测试时间
}

@end

@implementation TJPMessageParser
#pragma mark - Lifecycle
- (instancetype)init {
    return [self initWithRingBufferEnabled:NO];
}

- (instancetype)initWithRingBufferEnabled:(BOOL)enabled {
    if (self = [super init]) {
        _state = TJPParseStateHeader;
        _useRingBuffer = enabled;
        
        // 初始化缓冲区
        _buffer = [NSMutableData data];
        _ringBuffer = [[TJPRingBuffer alloc] initWithCapacity:TJP_DEFAULT_RING_BUFFER_CAPACITY];
        
        // 安全相关初始化
        _recentSequences = [NSMutableSet setWithCapacity:1000];
        _lastCleanupTime = [NSDate date];

        
        // 性能统计初始化
        _totalParseTime = 0;
        _totalPacketCount = 0;
        _lastBenchmarkTime = CFAbsoluteTimeGetCurrent();
        
        TJPLOG_INFO(@"MessageParser 初始化完成，使用%@缓冲区", _useRingBuffer ? @"环形" : @"传统");
        
    }
    return self;
}


#pragma mark - Public Method
- (void)feedData:(NSData *)data {
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();

    if (!data || data.length == 0) {
        return;
    }

    // 防止缓冲区过大导致内存耗尽
    if (data.length > TJPMAX_BUFFER_SIZE || (_buffer.length + data.length) > TJPMAX_BUFFER_SIZE) {
        TJPLOG_ERROR(@"数据大小超过限制: 当前缓冲区 %lu, 新增数据 %lu, 限制 %d", (unsigned long)_buffer.length, (unsigned long)data.length, TJPMAX_BUFFER_SIZE);
        [self reset];
        _state = TJPParseStateError;
        return;
    }
    
    // 根据开关选择实现
    if (_useRingBuffer) {
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
    
    if (_useRingBuffer) {
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
    if (_useRingBuffer) {
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

#pragma mark - Ring Buffer
- (void)feedDataWithRingBuffer:(NSData *)data {
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
        TJPLOG_INFO(@"环形缓冲区数据不足，无法解析头部");
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

#pragma mark Legacy Buffer
- (void)feedDataWithLegacyBuffer:(NSData *)data {
    @synchronized (self) {
        if ((_buffer.length + data.length) > TJPMAX_BUFFER_SIZE) {
            TJPLOG_ERROR(@"传统缓冲区大小超过限制: 当前 %lu, 新增 %lu, 限制 %d",
                         (unsigned long)_buffer.length, (unsigned long)data.length, TJPMAX_BUFFER_SIZE);
            [self reset];
            _state = TJPParseStateError;
            return;
        }
        
        [_buffer appendData:data];
    }
    
    //    TJPLOG_INFO(@"[传统Buffer] 收到数据: %lu 字节", (unsigned long)data.length);
}

- (BOOL)hasCompletePacketWithLegacyBuffer {
    if (_state == TJPParseStateHeader) {
        return _buffer.length >= sizeof(TJPFinalAdavancedHeader);
    } else if (_state == TJPParseStateBody) {
        uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
        return _buffer.length >= bodyLength;
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
    if (_buffer.length < sizeof(TJPFinalAdavancedHeader)) {
        TJPLOG_INFO(@"数据长度不够数据头解析");
        return nil;
    }
    TJPFinalAdavancedHeader currentHeader = {0};

    // 解析头部
    [_buffer getBytes:&currentHeader length:sizeof(TJPFinalAdavancedHeader)];
    
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
    [_buffer replaceBytesInRange:NSMakeRange(0, sizeof(TJPFinalAdavancedHeader)) withBytes:NULL length:0];
    
//    TJPLOG_INFO(@"解析序列号:%u 的头部成功", ntohl(_currentHeader.sequence));
    _state = TJPParseStateBody;
    
    return YES;
}

- (TJPParsedPacket *)parseBodyWithLegacyBuffer {
    uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
    if (_buffer.length < bodyLength) {
        TJPLOG_INFO(@"数据长度不够内容解析,等待更多数据...");
        return nil;
    }
    
    NSData *payload = [_buffer subdataWithRange:NSMakeRange(0, bodyLength)];
    [_buffer replaceBytesInRange:NSMakeRange(0, bodyLength) withBytes:NULL length:0];
    
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

- (void)reset {
    [_buffer setLength:0];
    [_ringBuffer reset];
    _currentHeader = (TJPFinalAdavancedHeader){0};
    _state = TJPParseStateHeader;
    
    TJPLOG_INFO(@"MessageParser 重置完成");
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



#pragma mark - 单元测试
- (NSMutableData *)buffer {
    return _buffer;
}


- (TJPFinalAdavancedHeader)currentHeader {
    return _currentHeader;
}
@end



