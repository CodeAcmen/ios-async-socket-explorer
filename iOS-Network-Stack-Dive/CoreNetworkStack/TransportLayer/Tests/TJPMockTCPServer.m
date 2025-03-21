//
//  TJPMockTCPServer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMockTCPServer.h"
#import <zlib.h>
#import "TJPNetworkProtocol.h"

@interface TJPMockTCPServer ()

@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) GCDAsyncSocket *connectedClient;


@end

@implementation TJPMockTCPServer

- (void)dealloc {
    NSLog(@"[MOCK SERVER] dealloc 被调用，MockServer 被销毁了！");
}

- (BOOL)startOnPort:(uint16_t)port error:(NSError **)error {
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    BOOL success = [self.serverSocket acceptOnPort:port error:error];
    if (success) {
        _port = port;
    }
    return success;
}

- (void)stop {
    [self.serverSocket disconnect];
    [self.connectedClient disconnect];
    self.serverSocket = nil;
    self.connectedClient = nil;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"[MOCK SERVER] 接收到客户端连接");
    self.connectedClient = newSocket;
    [self.connectedClient setDelegate:self delegateQueue:dispatch_get_main_queue()]; //  一步设置 delegate 和 queue
    [self.connectedClient readDataWithTimeout:-1 tag:0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSData *packet = [self buildPacketWithMessage:@"hello world"];
        [self.connectedClient writeData:packet withTimeout:-1 tag:0];
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"[MOCK SERVER] 收到客户端发来的数据长度: %lu", (unsigned long)data.length);

    const TJPAdavancedHeader *header = (const TJPAdavancedHeader *)data.bytes;
    if (ntohs(header->msgType) == TJPMessageTypeHeartbeat) {
        NSLog(@"[MOCK SERVER] 收到心跳包，序列号: %u", ntohl(header->sequence));

        // 构造心跳响应头
        TJPAdavancedHeader reply = {0};
        reply.magic = htonl(kProtocolMagic);
        reply.msgType = htons(TJPMessageTypeHeartbeat);
        reply.sequence = header->sequence; // 保持原网络字节序
        reply.bodyLength = htonl(0);

        // 计算校验和（将checksum字段置零后计算整个头部的CRC）
        reply.checksum = 0; // 临时置零
        uLong crc = crc32(0L, Z_NULL, 0);
        crc = crc32(crc, (const Bytef *)&reply, sizeof(reply));
        reply.checksum = htonl((uint32_t)crc);

        NSData *replyData = [NSData dataWithBytes:&reply length:sizeof(reply)];
        NSLog(@"[MOCK SERVER] 心跳响应包字段：magic=0x%X, msgType=%hu, sequence=%u, checksum=%u",
              ntohl(reply.magic), ntohs(reply.msgType), ntohl(reply.sequence), ntohl(reply.checksum));
        [sock writeData:replyData withTimeout:-1 tag:tag];
    }else if (ntohs(header->msgType) == TJPMessageTypeNormalData) {
        NSLog(@"[MOCK SERVER] 收到业务包，序列号: %u", ntohl(header->sequence));

        // 构造 ACK
        TJPAdavancedHeader ack = {0};
        ack.magic = htonl(kProtocolMagic);
        ack.msgType = htons(TJPMessageTypeACK);
        ack.sequence = header->sequence;
        ack.bodyLength = htonl(0);
        ack.checksum = htonl(0);

        NSData *ackData = [NSData dataWithBytes:&ack length:sizeof(ack)];
        [sock writeData:ackData withTimeout:-1 tag:tag];
    }

    [sock readDataWithTimeout:-1 tag:tag + 1];
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"[MOCK SERVER] socketDidDisconnect 被调用，服务端断开连接，err = %@", err);
}



#pragma mark - Public

- (void)sendPacket:(NSData *)packet {
    if (self.connectedClient.isConnected) {
        NSLog(@"[MOCK SERVER] 即将发送 packet，总长度: %lu", (unsigned long)packet.length);
        [self.connectedClient writeData:packet withTimeout:-1 tag:100];
    } else {
        NSLog(@"[MOCK SERVER] 写入失败：客户端未连接");
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"[MOCK SERVER] 数据写入完成，tag: %ld", tag);
}

- (NSData *)buildPacketWithMessage:(NSString *)message {
    TJPAdavancedHeader header = {0};
    NSData *payload = [message dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t payloadLength = (uint32_t)payload.length;

    // Header 构建
    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeNormalData);
    header.sequence = htonl(1);
    header.bodyLength = htonl((uint32_t)payloadLength);

    uLong crc = crc32(0L, Z_NULL, 0);
    header.checksum = htonl((uint32_t)crc32(crc, payload.bytes, payloadLength));

    // 拼接 header + payload
    NSMutableData *packet = [NSMutableData dataWithCapacity:sizeof(header) + payloadLength];
    [packet appendBytes:&header length:sizeof(header)];
    [packet appendData:payload];

    NSLog(@"构造 packet 完成，总长度: %lu", (unsigned long)packet.length);
    return packet;
}



@end
