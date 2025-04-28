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
    NSLog(@"[MOCK SERVER] 接收到客户端发送的数据");

    // 解析协议头
    if (data.length < kHeaderLength) {
        [sock readDataWithTimeout:-1 tag:0];
        return;
    }
    
    TJPFinalAdavancedHeader header;
    [data getBytes:&header length:kHeaderLength];
    
    
    // 验证Magic Number
    if (ntohl(header.magic) != kProtocolMagic) {
        NSLog(@"Invalid magic number");
        [sock disconnect];
        return;
    }
    
    // 解析消息内容
    uint32_t seq = ntohl(header.sequence);
    uint32_t bodyLength = ntohl(header.bodyLength);
    uint16_t msgType = ntohs(header.msgType);
    
    // 读取完整消息体
    NSData *payload = [data subdataWithRange:NSMakeRange(kHeaderLength, bodyLength)];
    
    // 校验checksum
    uint32_t receivedChecksum = ntohl(header.checksum);  // 转换为主机字节序
    uint32_t calculatedChecksum = [TJPNetworkUtil crc32ForData:payload];

    NSLog(@"[MOCK SERVER] 接收到的校验和: %u, 计算的校验和: %u", receivedChecksum, calculatedChecksum);

    if (receivedChecksum != calculatedChecksum) {
        NSLog(@"Checksum 不匹配, 期望: %u, 收到: %u", calculatedChecksum, receivedChecksum);
        [sock disconnect];
        return;
    }
    
    // 处理消息
    switch (msgType) {
        case TJPMessageTypeNormalData: // TJPMessageTypeNormalData
        {
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            [self sendACKForSequence:seq toSocket:sock];
        }
            break;
            
            
        case TJPMessageTypeHeartbeat: // TJPMessageTypeHeartbeat
        {
            if (self.didReceiveDataHandler) {
                self.didReceiveDataHandler(payload, seq);
            }
            [self sendHeartbeatACKForSequence:seq toSocket:sock];
        }
            
            break;
            
        default:
            NSLog(@"Received unknown message type: %d", msgType);
            break;
    }
    
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self.connectedSockets removeObject:sock];
}

#pragma mark - Response Methods
- (void)sendACKForSequence:(uint32_t)seq toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 收到普通消息，序列号: %u", seq);

    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = 1;
    header.version_minor = 0;
    header.msgType = htons(TJPMessageTypeACK);
    header.sequence = htonl(seq);
    header.bodyLength = 0;  // ACK没有数据体
    
    // ACK包没有数据体，checksum设为0
    header.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&header length:sizeof(header)];
    NSLog(@"[MOCK SERVER] 普通消息响应包字段：magic=0x%X, msgType=%hu, sequence=%u, checksum=%u",
          ntohl(header.magic), ntohs(header.msgType), ntohl(header.sequence), ntohl(header.checksum));
    
    [socket writeData:ackData withTimeout:-1 tag:0];
}


- (void)sendHeartbeatACKForSequence:(uint32_t)seq toSocket:(GCDAsyncSocket *)socket {
    NSLog(@"[MOCK SERVER] 收到心跳包，序列号: %u", seq);

    TJPFinalAdavancedHeader reply = {0};
    reply.magic = htonl(kProtocolMagic);
    reply.version_major = 1;
    reply.version_minor = 0;
    reply.msgType = htons(TJPMessageTypeHeartbeat);
    reply.sequence = htonl(seq);
    reply.bodyLength = 0;
    
    // 心跳ACK没有数据体，checksum设为0
    reply.checksum = 0;
    
    NSData *ackData = [NSData dataWithBytes:&reply length:sizeof(reply)];
    NSLog(@"[MOCK SERVER] 心跳响应包字段：magic=0x%X, msgType=%hu, sequence=%u, checksum=%u",
          ntohl(reply.magic), ntohs(reply.msgType), ntohl(reply.sequence), 0);
    [socket writeData:ackData withTimeout:-1 tag:0];
}

@end
