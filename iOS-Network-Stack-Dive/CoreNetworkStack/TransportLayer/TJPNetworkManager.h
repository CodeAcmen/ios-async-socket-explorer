//
//  TJPNetworkManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//  网络管理核心类

#import <Foundation/Foundation.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPNetworkManager : NSObject <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;


+ (instancetype)shared;
/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
/// 发送消息
- (void)sendData:(NSData *)data;

/// 重连策略
- (void)scheduleReconnect;
/// 重置连接
- (void)resetConnection;

@end

NS_ASSUME_NONNULL_END
