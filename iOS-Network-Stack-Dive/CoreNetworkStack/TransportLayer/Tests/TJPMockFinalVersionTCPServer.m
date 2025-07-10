//
//  TJPMockFinalVersionTCPServer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/25.
//  模拟服务端统一使用网络字节序 大端

#import "TJPMockFinalVersionTCPServer.h"
#import <zlib.h>
#import "TJPCoreTypes.h"
#import "TJPNetworkUtil.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkDefine.h"

static const NSUInteger kHeaderLength = sizeof(TJPFinalAdavancedHeader);

@interface TJPMockFinalVersionTCPServer ()
@property (nonatomic, strong) NSMutableData *receiveBuffer;

@property (nonatomic, strong) TJPSequenceManager *sequenceManager;


@end

@implementation TJPMockFinalVersionTCPServer

- (void)dealloc {
    NSLog(@"[MOCK SERVER] dealloc 被调用，MockServer 被销毁了！");
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectedSockets = [NSMutableArray array];
        _receiveBuffer = [NSMutableData data];
        
        // 初始化服务器端序列号管理器
        _sequenceManager = [[TJPSequenceManager alloc] initWithSessionId:@"mock_server_session"];
        
        NSLog(@"[MOCK SERVER] 初始化完成，序列号管理器已创建");
    }
    return self;
}

- (void)startWithPort:(uint16_t)port {
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if ([self.serverSocket acceptOnPort:port error:&error]) {
        self.port = port;
        NSLog(@"Mock server started on port %d", port);
    } else {
        NSLog(@"Failed to start mock server: %@", error);
    }
}

- (void)stop {
    [self.serverSocket disconnect];
    [self.connectedSockets makeObjectsPerformSelector:@selector(disconnect)];
    [self.connectedSockets removeAllObjects];
    NSLog(@"Mock server stopped");
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"[MOCK SERVER] 接收到客户端连接");
    [self.connectedSockets addObject:newSocket];
    // 先读取协议头
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"[MOCK SERVER] 📥 接收到客户端发送的数据，大小: %lu字节", (unsigned long)data.length);

    // 解析协议头
    if (data.length < kHeaderLength) {
        [sock readDataWithTimeout:-1 tag:0];
        return;
    }
    
    TJPFinalAdavancedHeader header;
    [data getBytes:&header length:kHeaderLength];
    
    
    // 验证Magic Number
    if (ntohl(header.magic) != kProtocolMagic) {
        NSLog(@"❌ Invalid magic number");
        [sock disconnect];
        return;
    }
    
    // 解析消息内容
    uint32_t seq = ntohl(header.sequence);
    uint32_t bodyLength = ntohl(header.bodyLength);
    uint16_t msgType = ntohs(header.msgType);
    TJPEncryptType encryptType = header.encrypt_type;
    TJPCompressType compressType = header.compress_type;
    uint16_t sessionId = ntohs(header.session_id);
    uint32_t timestamp = ntohl(header.timestamp);
    
    NSLog(@"[MOCK SERVER] 📥 解析消息: 类型=%hu, 序列号=%u, 时间戳=%u, 会话ID=%hu, 加密类型=%d, 压缩类型=%d",
         msgType, seq, timestamp, sessionId, encryptType, compressType);

    
    // 读取完整消息体
    NSData *payload = [data subdataWithRange:NSMakeRange(kHeaderLength, bodyLength)];
    
    // 校验checksum
    uint32_t receivedChecksum = ntohl(header.checksum);  // 转换为主机字节序
    uint32_t calculatedChecksum = [TJPNetworkUtil crc32ForData:payload];

    NSLog(@"[MOCK SERVER] 🔍 校验和检查: 接收=%u, 计算=%u", receivedChecksum, calculatedChecksum);

    if (receivedChecksum != calculatedChecksum) {
        NSLog(@"Checksum 不匹配, 期望: %u, 收到: %u", calculatedChecksum, receivedChecksum);
        [sock disconnect];
        return;
    }
    
    // 根据消息类型验证序列号类别
    [self validateReceivedMessage:msgType sequence:seq];
    
    // 处理消息
    switch (msgType) {
        case TJPMessageTypeNormalData: // 普通数据消息
        {
            NSLog(@"[MOCK SERVER] 🔄 处理普通消息，序列号: %u", seq);
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            // 发送传输层ACK
            [self sendACKForSequence:seq sessionId:sessionId toSocket:sock];
            
            // 模拟接收端自动发送已读回执
            [self simulateAutoReadReceiptForMessage:seq sessionId:sessionId toSocket:sock];
        }
            break;
            
            
        case TJPMessageTypeHeartbeat: // 心跳消息
        {
            NSLog(@"[MOCK SERVER] 💓 处理心跳消息，序列号: %u", seq);
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            [self sendHeartbeatACKForSequence:seq sessionId:sessionId toSocket:sock];
        }
            break;
        case TJPMessageTypeControl: // 控制消息
        {
            NSLog(@"[MOCK SERVER] 🎛️ 处理控制消息，序列号: %u", seq);
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            
            [self handleControlMessage:payload seq:seq sessionId:sessionId toSocket:sock];

            
            //发送控制消息ACK
            [self sendControlACKForSequence:seq sessionId:sessionId toSocket:sock];
        }
            
            break;
        case TJPMessageTypeReadReceipt: // 已读回执
        {
            NSLog(@"[MOCK SERVER] 收到已读回执，序列号: %u", seq);
            
            if (payload.length >= 4) {
                uint32_t originalMsgSeq = 0;
                memcpy(&originalMsgSeq, payload.bytes, sizeof(uint32_t));
                originalMsgSeq = ntohl(originalMsgSeq);
                
                NSLog(@"[MOCK SERVER] 消息序列号 %u 已被阅读", originalMsgSeq);
                
                // 模拟转发给其他客户端（实际项目中根据用户ID路由）
                [self forwardReadReceiptToOtherClients:payload fromSocket:sock];
            }
            
            // 发送ACK确认
            [self sendReadReceiptACK:seq sessionId:sessionId toSocket:sock];
        }
        break;
            
        case TJPMessageTypeACK:  // 🔧 添加这个
            NSLog(@"[MOCK SERVER] 收到ACK确认，序列号: %u", seq);
            // ACK消息通常不需要特殊处理，只需要记录即可
            break;
            
        default:
            NSLog(@"[MOCK SERVER] 收到未知消息类型 type: %d", msgType);
            break;
    }
    
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"[MOCK SERVER] ✅ 数据发送完成，tag: %ld", tag);
    if (tag > 0) {
        NSLog(@"[MOCK SERVER] ✅ ACK包发送成功，序列号: %ld", tag);
    }
}

// 5. 添加错误处理
- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"[MOCK SERVER] 📤 部分数据发送: %lu字节, tag: %ld", (unsigned long)partialLength, tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self.connectedSockets removeObject:sock];
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveError:(NSError *)error {
    NSLog(@"[MOCK SERVER] ❌ Socket错误: %@", error.localizedDescription);
}


#pragma mark - Response Methods
- (void)sendACKForSequence:(uint32_t)seq sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 📤 准备发送普通消息ACK，序列号: %u", seq);

    // 使用与客户端相同的时间戳生成ACK响应
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];


    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeACK);
    header.sequence = htonl(seq);
    header.timestamp = htonl(currentTime);  // 使用当前时间戳
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons(sessionId);  // 保持与请求相同的会话ID
    
    header.bodyLength = 0;  // ACK没有数据体
    // ACK包没有数据体，checksum设为0
    header.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&header length:sizeof(header)];
    
    NSLog(@"[MOCK SERVER] 📤 即将发送普通消息ACK包，大小: %lu字节", (unsigned long)ackData.length);
    NSLog(@"[MOCK SERVER] 📤 ACK包字段：magic=0x%X, msgType=%hu, sequence=%u, timestamp=%u, sessionId=%hu",
          ntohl(header.magic), ntohs(header.msgType), ntohl(header.sequence), ntohl(header.timestamp), ntohs(header.session_id));

    [socket writeData:ackData withTimeout:10.0 tag:0];
    
    NSLog(@"[MOCK SERVER] ✅ 普通消息ACK包已提交发送，序列号: %u", seq);

}

- (void)sendControlACKForSequence:(uint32_t)seq sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 📤 准备发送控制消息ACK，序列号: %u", seq);

    // 使用当前时间戳
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];

    TJPFinalAdavancedHeader reply = {0};
    reply.magic = htonl(kProtocolMagic);
    reply.version_major = kProtocolVersionMajor;
    reply.version_minor = kProtocolVersionMinor;
    reply.msgType = htons(TJPMessageTypeACK);  // 仍然使用ACK类型，但可以考虑使用TJPMessageTypeControl
    reply.sequence = htonl(seq);
    reply.timestamp = htonl(currentTime);
    reply.encrypt_type = TJPEncryptTypeNone;
    reply.compress_type = TJPCompressTypeNone;
    reply.session_id = htons(sessionId);
    reply.bodyLength = 0;
    
    // 没有数据体，checksum设为0
    reply.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&reply length:sizeof(reply)];
    NSLog(@"[MOCK SERVER] 📤 即将发送控制消息ACK包，大小: %lu字节", (unsigned long)ackData.length);
    NSLog(@"[MOCK SERVER] 📤 控制ACK包字段：magic=0x%X, msgType=%hu, sequence=%u, timestamp=%u, sessionId=%hu",
          ntohl(reply.magic), ntohs(reply.msgType), ntohl(reply.sequence), ntohl(reply.timestamp), ntohs(reply.session_id));
    
    [socket writeData:ackData withTimeout:10.0 tag:0];
    
    NSLog(@"[MOCK SERVER] ✅ 控制消息ACK包已提交发送，序列号: %u", seq);
}

- (void)handleControlMessage:(NSData *)payload seq:(uint32_t)seq sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    // 现有的版本协商逻辑
    if (payload.length >= 12) {
        // TLV解析逻辑（保持不变）
        uint16_t tag;
        uint32_t length;
        uint16_t value;
        uint16_t flags;
        
        const void *bytes = payload.bytes;
        memcpy(&tag, bytes, sizeof(uint16_t));
        memcpy(&length, bytes + 2, sizeof(uint32_t));
        memcpy(&value, bytes + 6, sizeof(uint16_t));
        memcpy(&flags, bytes + 8, sizeof(uint16_t));
        
        tag = ntohs(tag);
        length = ntohl(length);
        value = ntohs(value);
        flags = ntohs(flags);
        
        NSLog(@"[MOCK SERVER] 版本协商：Tag=%u, Length=%u, Value=0x%04X, Flags=0x%04X",
              tag, length, value, flags);
        
        if (tag == 0x0001) {
            uint8_t clientMajorVersion = (value >> 8) & 0xFF;
            uint8_t clientMinorVersion = value & 0xFF;
            
            NSLog(@"[MOCK SERVER] 客户端版本: %u.%u", clientMajorVersion, clientMinorVersion);
            NSLog(@"[MOCK SERVER] 客户端特性: %@", [self featureDescriptionWithFlags:flags]);
            
            [self sendVersionNegotiationResponseForSequence:seq sessionId:sessionId clientVersion:value
                                          supportedFeatures:flags toSocket:socket];
        }
    }
    
    [self sendControlACKForSequence:seq sessionId:sessionId toSocket:socket];
}


- (void)sendHeartbeatACKForSequence:(uint32_t)seq sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 收到心跳包，序列号: %u", seq);
    
    
    // 使用当前时间戳
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];

    TJPFinalAdavancedHeader reply = {0};
    reply.magic = htonl(kProtocolMagic);
    reply.version_major = kProtocolVersionMajor;
    reply.version_minor = kProtocolVersionMinor;
    reply.msgType = htons(TJPMessageTypeACK);
    reply.sequence = htonl(seq);
    reply.timestamp = htonl(currentTime);  // 使用当前时间戳
    reply.encrypt_type = TJPEncryptTypeNone;
    reply.compress_type = TJPCompressTypeNone;
    reply.session_id = htons(sessionId);   // 保持与请求相同的会话ID
    reply.bodyLength = 0;
    
    // 心跳ACK没有数据体，checksum设为0
    reply.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&reply length:sizeof(reply)];
    NSLog(@"[MOCK SERVER] 心跳响应包字段：magic=0x%X, msgType=%hu, sequence=%u, timestamp=%u, sessionId=%hu",
          ntohl(reply.magic), ntohs(reply.msgType), ntohl(reply.sequence), ntohl(reply.timestamp), ntohs(reply.session_id));
    [socket writeData:ackData withTimeout:-1 tag:0];
}


- (void)sendVersionNegotiationResponseForSequence:(uint32_t)seq sessionId:(uint16_t)sessionId clientVersion:(uint16_t)clientVersion supportedFeatures:(uint16_t)features toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 收到控制消息，序列号: %u", seq);

    // 使用当前时间戳
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];
    
    // 服务器选择的版本和功能
    uint8_t serverMajorVersion = kProtocolVersionMajor;
    uint8_t serverMinorVersion = kProtocolVersionMinor;
    uint16_t serverVersion = (serverMajorVersion << 8) | serverMinorVersion;
    uint16_t agreedFeatures = features & 0x000F; // 仅支持客户端请求的部分功能

    // 构建TLV数据
    NSMutableData *tlvData = [NSMutableData data];
    
    // 版本协商响应TLV
    uint16_t versionResponseTag = htons(0x0002); // 响应标签
    uint32_t versionResponseLength = htonl(4);
    uint16_t versionResponseValue = htons(serverVersion);
    uint16_t agreedFeaturesValue = htons(agreedFeatures);
    
    [tlvData appendBytes:&versionResponseTag length:sizeof(uint16_t)];
    [tlvData appendBytes:&versionResponseLength length:sizeof(uint32_t)];
    [tlvData appendBytes:&versionResponseValue length:sizeof(uint16_t)];
    [tlvData appendBytes:&agreedFeaturesValue length:sizeof(uint16_t)];
    
    // 计算校验和
    uint32_t checksum = [TJPNetworkUtil crc32ForData:tlvData];
    
    // 构建响应头
    TJPFinalAdavancedHeader responseHeader = {0};
    responseHeader.magic = htonl(kProtocolMagic);
    responseHeader.version_major = serverMajorVersion;
    responseHeader.version_minor = serverMinorVersion;
    responseHeader.msgType = htons(TJPMessageTypeControl);
    responseHeader.sequence = htonl(seq + 1); // 响应序列号+1
    responseHeader.timestamp = htonl(currentTime);
    responseHeader.encrypt_type = TJPEncryptTypeNone;
    responseHeader.compress_type = TJPCompressTypeNone;
    responseHeader.session_id = htons(sessionId);
    responseHeader.bodyLength = htonl((uint32_t)tlvData.length);
    responseHeader.checksum = htonl(checksum);
    
    // 构建完整响应
    NSMutableData *responseData = [NSMutableData dataWithBytes:&responseHeader
                                                        length:sizeof(responseHeader)];
    [responseData appendData:tlvData];
    
    NSLog(@"[MOCK SERVER] 发送版本协商响应：服务器版本 %u.%u，协商功能 0x%04X",
          serverMajorVersion, serverMinorVersion, agreedFeatures);
    
    [socket writeData:responseData withTimeout:-1 tag:0];

}

// 模拟自动已读回执
- (void)simulateAutoReadReceiptForMessage:(uint32_t)originalSequence sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 🤖 开始模拟自动已读回执，原消息序列号: %u", originalSequence);
    
    // 延迟2秒模拟用户阅读时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendReadReceiptToClientForMessage:originalSequence sessionId:sessionId toSocket:socket];
    });
}

// 向客户端发送已读回执 - 统一使用网络字节序
- (void)sendReadReceiptToClientForMessage:(uint32_t)originalSequence sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 📖 模拟发送已读回执，原消息序列号: %u", originalSequence);
    
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];
    uint32_t readReceiptSeq = [self.sequenceManager nextSequenceForCategory:TJPMessageCategoryNormal];
    
    // 🔧 关键修复：使用TLV格式包装已读回执数据
    NSMutableData *readReceiptData = [NSMutableData data];
    
    // 构建TLV格式的已读回执
    // Tag: 已读回执标签 (假设使用 0x0001)
    uint16_t tag = htons(0x0001);
    [readReceiptData appendBytes:&tag length:sizeof(uint16_t)];
    
    // Length: 数据长度 (4字节序列号)
    uint32_t length = htonl(4);
    [readReceiptData appendBytes:&length length:sizeof(uint32_t)];
    
    // Value: 原消息序列号 (网络字节序)
    uint32_t networkSequence = htonl(originalSequence);
    [readReceiptData appendBytes:&networkSequence length:sizeof(uint32_t)];
    
    // 🔍 调试信息 - 验证网络字节序
    NSLog(@"[MOCK SERVER] 🔍 统一网络字节序调试：");
    NSLog(@"[MOCK SERVER] 🔍   原序列号(主机序): %u (0x%08X)", originalSequence, originalSequence);
    NSLog(@"[MOCK SERVER] 🔍   网络字节序: 0x%08X", networkSequence);
    NSLog(@"[MOCK SERVER] 🔍   逆向验证: %u", ntohl(networkSequence));
    NSLog(@"[MOCK SERVER] 🔍   数据长度: %lu", (unsigned long)readReceiptData.length);
    
    // 以十六进制打印网络字节序数据
    const unsigned char *bytes = readReceiptData.bytes;
    NSMutableString *hexString = [NSMutableString string];
    for (NSUInteger i = 0; i < readReceiptData.length; i++) {
        [hexString appendFormat:@"%02X ", bytes[i]];
    }
    NSLog(@"[MOCK SERVER] 🔍   TLV十六进制: %@", hexString);
    
    // 🔧 关键：对网络字节序数据计算校验和
    uint32_t checksum = [TJPNetworkUtil crc32ForData:readReceiptData];
    NSLog(@"[MOCK SERVER] 🔍   网络字节序CRC32: %u (0x%08X)", checksum, checksum);
    
    // 构建包头 - 已读回执有自己独立的序列号
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeReadReceipt);
    header.sequence = htonl(readReceiptSeq);  // 使用独立的序列号
    header.timestamp = htonl(currentTime);
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons(sessionId);
    header.bodyLength = htonl((uint32_t)readReceiptData.length);
    header.checksum = checksum;  // 🔧 关键修复：校验和不做字节序转换！
    
    // 🔍 调试包头信息
    NSLog(@"[MOCK SERVER] 🔍 包头调试信息：");
    NSLog(@"[MOCK SERVER] 🔍   magic: 0x%08X", ntohl(header.magic));
    NSLog(@"[MOCK SERVER] 🔍   msgType: %hu", ntohs(header.msgType));
    NSLog(@"[MOCK SERVER] 🔍   sequence: %u", ntohl(header.sequence));
    NSLog(@"[MOCK SERVER] 🔍   timestamp: %u", ntohl(header.timestamp));
    NSLog(@"[MOCK SERVER] 🔍   sessionId: %hu", ntohs(header.session_id));
    NSLog(@"[MOCK SERVER] 🔍   bodyLength: %u", ntohl(header.bodyLength));
    NSLog(@"[MOCK SERVER] 🔍   checksum(网络序): 0x%08X", ntohl(header.checksum));
    NSLog(@"[MOCK SERVER] 🔍   checksum(主机序): %u", checksum);
    
    // 构建完整的已读回执包
    NSMutableData *readReceiptPacket = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [readReceiptPacket appendData:readReceiptData];
    
    // 发送数据
    [socket writeData:readReceiptPacket withTimeout:-1 tag:0];
    
    NSLog(@"[MOCK SERVER] ✅ 已读回执已发送（TLV格式），序列号: %u，确认原消息: %u", readReceiptSeq, originalSequence);
}

// 转发已读回执
- (void)forwardReadReceiptToOtherClients:(NSData *)readReceiptPayload fromSocket:(GCDAsyncSocket *)senderSocket {
    // 简单实现：转发给除发送者外的所有连接
    for (GCDAsyncSocket *socket in self.connectedSockets) {
        if (socket != senderSocket) {
            [self sendReadReceiptToSocket:socket payload:readReceiptPayload];
        }
    }
}

// 转发已读回执给客户端
- (void)sendReadReceiptToSocket:(GCDAsyncSocket *)socket payload:(NSData *)readReceiptPayload {
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];
    uint32_t forwardSeq = [self.sequenceManager nextSequenceForCategory:TJPMessageCategoryNormal];

    NSLog(@"[MOCK SERVER] 📤 转发已读回执，序列号: %u", forwardSeq);

    // 🔧 注意：这里的 payload 应该已经是正确的网络字节序格式
    // 因为它是从客户端接收到的，客户端期望的格式
    
    // 计算校验和
    uint32_t checksum = [TJPNetworkUtil crc32ForData:readReceiptPayload];
    
    // 构建转发包
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeReadReceipt);
    header.sequence = htonl(forwardSeq);
    header.timestamp = htonl(currentTime);
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons(1234); // 简化处理
    header.bodyLength = htonl((uint32_t)readReceiptPayload.length);
    header.checksum = htonl(checksum);
    
    NSMutableData *forwardPacket = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [forwardPacket appendData:readReceiptPayload];
    
    [socket writeData:forwardPacket withTimeout:-1 tag:0];
    
    NSLog(@"[MOCK SERVER] 📤 已读回执已转发，序列号: %u", forwardSeq);
}
// 发送已读回执ACK
- (void)sendReadReceiptACK:(uint32_t)seq sessionId:(uint16_t)sessionId toSocket:(GCDAsyncSocket *)socket {
    uint32_t currentTime = (uint32_t)[[NSDate date] timeIntervalSince1970];
    
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(TJPMessageTypeACK);
    header.sequence = htonl(seq);
    header.timestamp = htonl(currentTime);
    header.encrypt_type = TJPEncryptTypeNone;
    header.compress_type = TJPCompressTypeNone;
    header.session_id = htons(sessionId);
    header.bodyLength = 0;
    header.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&header length:sizeof(header)];
    [socket writeData:ackData withTimeout:10.0 tag:0];
    
    NSLog(@"[MOCK SERVER] ✅ 已读回执ACK已发送，序列号: %u", seq);
}

- (NSString *)featureDescriptionWithFlags:(uint16_t)flags {
    NSMutableString *desc = [NSMutableString string];
    
    if (flags & 0x0001) [desc appendString:@"基本消息 "];
    if (flags & 0x0002) [desc appendString:@"加密 "];
    if (flags & 0x0004) [desc appendString:@"压缩 "];
    if (flags & 0x0008) [desc appendString:@"已读回执 "];
    if (flags & 0x0010) [desc appendString:@"群聊 "];
    
    return desc.length > 0 ? desc : @"无特性";
}


- (void)logSequenceManagerStats {
    NSDictionary *stats = [self.sequenceManager getStatistics];
    
    NSLog(@"[MOCK SERVER] 📊 序列号管理器统计:");
    NSLog(@"[MOCK SERVER] 📊 会话ID: %@", stats[@"sessionId"]);
    NSLog(@"[MOCK SERVER] 📊 会话种子: %@", stats[@"sessionSeed"]);
    
    // 输出各类别统计
    for (int i = 0; i < 4; i++) {
        NSString *categoryKey = [NSString stringWithFormat:@"category_%d", i];
        NSDictionary *categoryStats = stats[categoryKey];
        if (categoryStats) {
            NSString *categoryName = [self categoryNameForIndex:i];
            NSLog(@"[MOCK SERVER] 📊 %@: 当前=%@, 总数=%@, 利用率=%.1f%%",
                  categoryName,
                  categoryStats[@"current"],
                  categoryStats[@"total_generated"],
                  [categoryStats[@"utilization"] doubleValue]);
        }
    }
}

// 类别名称映射
- (NSString *)categoryNameForIndex:(int)index {
    switch (index) {
        case TJPMessageCategoryNormal:
            return @"普通消息";
        case TJPMessageCategoryControl:
            return @"控制消息";
        case TJPMessageCategoryHeartbeat:
            return @"心跳消息";
        case TJPMessageCategoryBroadcast:
            return @"广播消息";
        default:
            return [NSString stringWithFormat:@"未知类别_%d", index];
    }
}

- (void)validateSequenceNumber:(uint32_t)sequence expectedCategory:(TJPMessageCategory)expectedCategory {
    BOOL isCorrectCategory = [self.sequenceManager isSequenceForCategory:sequence category:expectedCategory];
    
    // 提取类别和序列号
    uint8_t category = (sequence >> TJPSEQUENCE_BODY_BITS) & TJPSEQUENCE_CATEGORY_MASK;
    uint32_t seqNumber = sequence & TJPSEQUENCE_BODY_MASK;
    
    NSLog(@"[MOCK SERVER] 🔍 序列号验证: %u", sequence);
    NSLog(@"[MOCK SERVER] 🔍   - 类别: %d (%@)", category, [self categoryNameForIndex:category]);
    NSLog(@"[MOCK SERVER] 🔍   - 序列号: %u", seqNumber);
    NSLog(@"[MOCK SERVER] 🔍   - 期望类别: %d (%@)", (int)expectedCategory, [self categoryNameForIndex:expectedCategory]);
    NSLog(@"[MOCK SERVER] 🔍   - 类别匹配: %@", isCorrectCategory ? @"✅" : @"❌");
}

- (void)validateReceivedMessage:(uint16_t)msgType sequence:(uint32_t)sequence {
    TJPMessageCategory expectedCategory;
    
    switch (msgType) {
        case TJPMessageTypeNormalData:
        case TJPMessageTypeReadReceipt:
            expectedCategory = TJPMessageCategoryNormal;
            break;
        case TJPMessageTypeControl:
            expectedCategory = TJPMessageCategoryControl;
            break;
        case TJPMessageTypeHeartbeat:
            expectedCategory = TJPMessageCategoryHeartbeat;
            break;
        case TJPMessageTypeACK:
            // ACK消息的序列号类别取决于它确认的原消息类型
            // 但由于我们无法从序列号直接确定原消息类型，可以跳过验证
            NSLog(@"[MOCK SERVER] 🔍 ACK消息序列号验证跳过: %u", sequence);
            return;
        default:
            NSLog(@"[MOCK SERVER] ⚠️ 未知消息类型 %hu，跳过序列号验证", msgType);
            return;
    }
    
    BOOL isValid = [self.sequenceManager isSequenceForCategory:sequence category:expectedCategory];
    if (!isValid) {
        NSLog(@"[MOCK SERVER] ⚠️ 序列号类别不匹配！消息类型: %hu, 序列号: %u, 期望类别: %d",
              msgType, sequence, (int)expectedCategory);
    }
}


//旧方法 已废弃目前单元测试在用 后续移除
- (void)sendHeartbeatACKForSequence:(uint32_t)seq toSocket:(nonnull GCDAsyncSocket *)socket {
}

- (void)sendACKForSequence:(uint32_t)seq toSocket:(nonnull GCDAsyncSocket *)socket {
}


@end
