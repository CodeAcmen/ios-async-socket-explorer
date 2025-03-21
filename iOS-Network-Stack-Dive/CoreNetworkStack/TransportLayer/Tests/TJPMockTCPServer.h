//
//  TJPMockTCPServer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  单元测试的mock TCP服务器

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPMockTCPServer : NSObject <GCDAsyncSocketDelegate>

@property (nonatomic, strong, readonly) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong, readonly) GCDAsyncSocket *connectedClient;

@property (nonatomic, assign, readonly) uint16_t port;

// 启动服务
- (BOOL)startOnPort:(uint16_t)port error:(NSError **)error;

// 停止服务
- (void)stop;

// 发送模拟数据（完整数据包）
- (void)sendPacket:(NSData *)packet;

// 用字符串构建完整数据包（Header + Payload）
- (NSData *)buildPacketWithMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
