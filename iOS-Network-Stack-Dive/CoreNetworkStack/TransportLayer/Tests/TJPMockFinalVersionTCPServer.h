//
//  TJPMockFinalVersionTCPServer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>


NS_ASSUME_NONNULL_BEGIN

@interface TJPMockFinalVersionTCPServer : NSObject <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) NSMutableArray<GCDAsyncSocket *> *connectedSockets;
@property (nonatomic, copy) void (^didReceiveDataHandler)(NSData *data, uint32_t seq);
@property (nonatomic, assign) uint16_t port;

- (void)startWithPort:(uint16_t)port;
- (void)stop;
- (void)sendACKForSequence:(uint32_t)seq toSocket:(GCDAsyncSocket *)socket;
- (void)sendHeartbeatACKForSequence:(uint32_t)seq toSocket:(GCDAsyncSocket *)socket;

@end

NS_ASSUME_NONNULL_END
