//
//  SolutionStickyPacketServer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import "SolutionStickyPacketServer.h"
#import "GCDAsyncSocket.h"


@interface SolutionStickyPacketServer () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) NSMutableArray<GCDAsyncSocket *> *clientSockets;



@end

@implementation SolutionStickyPacketServer

- (instancetype)init {
    if (self = [super init]) {
        self.clientSockets = [NSMutableArray array];
    }
    return self;
}

- (void)startServerOnPort:(uint16_t)port {
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![self.serverSocket acceptOnPort:port error:&error]) {
        NSLog(@"Server failed to start: %@", error);
    }else {
        NSLog(@"Server started on port %d", port);
    }
}

- (void)stopServer {
    [self.serverSocket disconnect];
    NSLog(@"Server stopped");
}


#pragma mark - Private Method
- (void)readMessageHeader:(GCDAsyncSocket *)socket {
    [socket readDataToLength:4 withTimeout:-1 tag:0];
}

- (void)readMessageBody:(GCDAsyncSocket *)socket length:(uint32_t)length {
    [socket readDataToLength:length withTimeout:-1 tag:1];
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [self.clientSockets addObject:newSocket];
    NSLog(@"New client connected: %@", newSocket.connectedHost);
        
    //读取header
    [self readMessageHeader:newSocket];
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag {
    if (tag == 0) {
        //读取消息头
        uint32_t messageLength = 0;
        [data getBytes:&messageLength length:sizeof(messageLength)];
        //转换为网络字节序
        messageLength = ntohl(messageLength);
        
        //根据消息长度读取消息体
        [self readMessageBody:socket length:messageLength];
    }else if (tag == 1) {
        //读取消息体
        NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Received message: %@", message);
        
        //回复客户端
        NSString *response = [NSString stringWithFormat:@"Echo: %@", message];
        NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
        
        //发送消息头+消息体
        uint32_t responseLength = (uint32_t)responseData.length;
        //转换为网络字节序
        responseLength = ntohl(responseLength);
        NSData *headerData = [NSData dataWithBytes:&responseLength length:sizeof(responseLength)];
        
        NSMutableData *finData = [NSMutableData data];
        [finData appendData:headerData];
        [finData appendData:responseData];
        
        [socket writeData:finData withTimeout:-1 tag:0];
        
        //继续读取消息头
        [self readMessageHeader:socket];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    //客户端断开连接
    [self.clientSockets removeObject:sock];
    NSLog(@"Client disconnected");
}



@end
