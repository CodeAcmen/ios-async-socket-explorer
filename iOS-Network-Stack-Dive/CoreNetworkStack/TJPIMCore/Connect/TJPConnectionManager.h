//
//  TJPConnectionManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/15.
//

#import <Foundation/Foundation.h>
#import "TJPConnectionDelegate.h"
#import "TJPCoreTypes.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPConnectionManager : NSObject

@property (nonatomic, weak) id<TJPConnectionDelegate> delegate;
/// 内部状态
@property (nonatomic, readonly) TJPConnectionState internalState;
/// 当前主机
@property (nonatomic, readonly) NSString *currentHost;
/// 当前端口
@property (nonatomic, readonly) uint16_t currentPort;
/// 断开原因
@property (nonatomic, readonly) TJPDisconnectReason disconnectReason;
/// 使用TLS 默认为NO方便单元测试
@property (nonatomic, assign) BOOL useTLS;
/// 连接时限窗口 默认30秒
@property (nonatomic, assign) NSTimeInterval connectionTimeout;

/// 标志位
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) BOOL isConnecting;

/// 初始化方法
- (instancetype)initWithDelegateQueue:(dispatch_queue_t)delegateQueue;
/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
/// 断开连接方法
- (void)disconnect;
/// 强制断开连接方法
- (void)forceDisconnect;
/// 断开连接原因
- (void)disconnectWithReason:(TJPDisconnectReason)reason;
/// 发送消息
- (void)sendData:(NSData *)data;
/// 带超时的发送消息
- (void)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
/// 开始TLS
- (void)startTLS:(NSDictionary *)settings;

/// 首次握手版本协商
- (void)setVersionInfo:(uint8_t)majorVersion minorVersion:(uint8_t)minorVersion;


@end

NS_ASSUME_NONNULL_END
