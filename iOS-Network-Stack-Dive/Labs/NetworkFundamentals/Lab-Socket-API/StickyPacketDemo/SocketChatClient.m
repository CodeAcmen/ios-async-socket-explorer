//
//  SocketChatClient.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//

#import "SocketChatClient.h"
#import "GCDAsyncSocket.h"

@interface SocketChatClient () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *client;


@end

@implementation SocketChatClient

- (instancetype)init {
    if (self = [super init]) {
        dispatch_queue_t serialQueue = dispatch_queue_create("com.SocketChatClient.client", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(serialQueue,
        dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        self.client = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serialQueue];
    }
    return self;
}

- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    NSError *error;
    if (![self.client connectToHost:host onPort:port error:&error]) {
        NSLog(@"Connect failed: %@", error);
    }else {
        NSLog(@"Connecting to %@:%d", host, port);
    }
}

- (void)sendMessage:(NSString *)message {
    NSLog(@"Send Message :%@", message);
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    //-1代表无限等待，永不超时
    [self.client writeData:data withTimeout:-1 tag:0];
    [self.client readDataWithTimeout:-1 tag:0];
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    //连接成功
    NSLog(@"Connected to server");
    [sock readDataWithTimeout:-1 tag:0];

}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"[Server]: %@", msg);
    [sock readDataWithTimeout:-1 tag:0];

}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"Client disconnected: %@", err);
}


@end
