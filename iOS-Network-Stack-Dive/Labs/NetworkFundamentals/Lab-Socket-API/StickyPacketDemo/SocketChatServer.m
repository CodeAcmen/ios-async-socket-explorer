//
//  SocketChatServer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//

#import "SocketChatServer.h"
#import "GCDAsyncSocket.h"

@interface SocketChatServer () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) NSMutableArray<GCDAsyncSocket *> *clientSockets;


@end

@implementation SocketChatServer

- (instancetype)init {
    if (self = [super init]) {
        self.clientSockets = [NSMutableArray array];
    }
    return self;
}

- (void)startServerOnPort:(uint16_t)port {
    dispatch_queue_t serialQueue = dispatch_queue_create("com.SocketChatServer.server", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(serialQueue,
    dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serialQueue];
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

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [self.clientSockets addObject:newSocket];
    //新客户端接入
    NSLog(@"Client connected: %@", newSocket.connectedHost);
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag {
    //收到消息
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Received: %@", msg);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(didReceiveMessageFromClient:)]) {
        [self.delegate didReceiveMessageFromClient:msg];
    }

    for (GCDAsyncSocket *client in self.clientSockets) {
        if (client != socket) {
            [client writeData:data withTimeout:-1 tag:0];
        }
    }
    //继续等待数据
    [socket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    //客户端断开连接
    [self.clientSockets removeObject:sock];
    NSLog(@"Client disconnected");
}
@end
