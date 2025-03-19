//
//  SolutionStickyPacketClient.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import "SolutionStickyPacketClient.h"
#import "GCDAsyncSocket.h"


@interface SolutionStickyPacketClient () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *client;


@end

@implementation SolutionStickyPacketClient

- (instancetype)init {
    if (self = [super init]) {
        self.client = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
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
    NSLog(@"Send Message: %@", message);
    //消息体数据
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t messageLength = (uint32_t)messageData.length;
    //转换成网络字节序
    messageLength = ntohl(messageLength);
    
    //消息头
    NSData *headerData = [NSData dataWithBytes:&messageLength length:sizeof(messageLength)];
    
    NSMutableData *finData = [NSMutableData data];
    [finData appendData:headerData];
    [finData appendData:messageData];
    
    [self.client writeData:finData withTimeout:-1 tag:0];
    [self.client readDataWithTimeout:-1 tag:0];
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    //连接成功
    NSLog(@"Connected to server");
    [sock readDataWithTimeout:-1 tag:0];

}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (tag == 0) {
        //先读取消息头长度
        uint32_t messageLength = 0;
        [data getBytes:&messageLength length:sizeof(messageLength)];
        messageLength = ntohl(messageLength);
        //继续读取消息体
        [sock readDataToLength:messageLength withTimeout:-1 tag:1];
    }else if (tag == 1) {
        NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Received from server: %@", response);
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"Client disconnected: %@", err);
}

@end
