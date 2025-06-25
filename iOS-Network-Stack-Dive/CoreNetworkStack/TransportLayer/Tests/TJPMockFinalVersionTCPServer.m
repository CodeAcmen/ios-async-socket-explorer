//
//  TJPMockFinalVersionTCPServer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import "TJPMockFinalVersionTCPServer.h"
#import <zlib.h>
#import "TJPCoreTypes.h"
#import "TJPNetworkUtil.h"

static const NSUInteger kHeaderLength = sizeof(TJPFinalAdavancedHeader);

@interface TJPMockFinalVersionTCPServer ()
@property (nonatomic, strong) NSMutableData *receiveBuffer;

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
    
    // 处理消息
    switch (msgType) {
        case TJPMessageTypeNormalData: // 普通数据消息
        {
            NSLog(@"[MOCK SERVER] 🔄 处理普通消息，序列号: %u", seq);
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            [self sendACKForSequence:seq sessionId:sessionId toSocket:sock];
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
            
            //解析TLV数据,获取版本信息
            if (payload.length >= 12) {
                //Tag(2) + Length(4) + Value(2) + Flags(2)
                uint16_t tag;
                uint32_t length;
                uint16_t value;
                uint16_t flags;
                
                const void *bytes = payload.bytes;
                memcpy(&tag, bytes, sizeof(uint16_t));
                memcpy(&length, bytes + 2, sizeof(uint32_t));
                memcpy(&value, bytes + 6, sizeof(uint16_t));
                memcpy(&flags, bytes + 8, sizeof(uint16_t));
                
                // 转换网络字节序到主机字节序
                tag = ntohs(tag);
                length = ntohl(length);
                value = ntohs(value);
                flags = ntohs(flags);
                
                NSLog(@"[MOCK SERVER] 版本协商：Tag=%u, Length=%u, Value=0x%04X, Flags=0x%04X",
                      tag, length, value, flags);
                
                if (tag == 0x0001) { // 版本标签
                    uint8_t clientMajorVersion = (value >> 8) & 0xFF;
                    uint8_t clientMinorVersion = value & 0xFF;
                    
                    NSLog(@"[MOCK SERVER] 客户端版本: %u.%u", clientMajorVersion, clientMinorVersion);
                    
                    NSLog(@"[MOCK SERVER] 客户端特性: %@", [self featureDescriptionWithFlags:flags]);

                    
                    // 发送版本协商响应
                    [self sendVersionNegotiationResponseForSequence:seq sessionId:sessionId clientVersion:value
                                                  supportedFeatures:flags toSocket:sock];
                }
            }
            
            //发送控制消息ACK
            [self sendControlACKForSequence:seq sessionId:sessionId toSocket:sock];
        }
            
            break;
            
        default:
            NSLog(@"Received unknown message type: %d", msgType);
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
    uint16_t agreedFeatures = features & 0x0003; // 仅支持客户端请求的部分功能

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

- (NSString *)featureDescriptionWithFlags:(uint16_t)flags {
    NSMutableString *desc = [NSMutableString string];
    
    if (flags & 0x0001) [desc appendString:@"基本消息 "];
    if (flags & 0x0002) [desc appendString:@"加密 "];
    if (flags & 0x0004) [desc appendString:@"压缩 "];
    if (flags & 0x0008) [desc appendString:@"已读回执 "];
    if (flags & 0x0010) [desc appendString:@"群聊 "];
    
    return desc.length > 0 ? desc : @"无特性";
}


//旧方法 已废弃目前单元测试在用 后续移除
- (void)sendHeartbeatACKForSequence:(uint32_t)seq toSocket:(nonnull GCDAsyncSocket *)socket {
}

- (void)sendACKForSequence:(uint32_t)seq toSocket:(nonnull GCDAsyncSocket *)socket {
}

@end
