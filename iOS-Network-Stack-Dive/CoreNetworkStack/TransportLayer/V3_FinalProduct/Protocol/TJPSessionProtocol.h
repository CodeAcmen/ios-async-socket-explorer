//
//  TJPSessionProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
@protocol TJPSessionProtocol <NSObject>

/// 状态获取
@property (nonatomic, readonly) TJPConnectState connectState;
/// 每个会话会有独立的id  使用UUID保证唯一
@property (nonatomic, copy, readonly) NSString *sessionId;
/// 主机地址
@property (nonatomic, readonly) NSString *host;
/// 端口号
@property (nonatomic, readonly) uint16_t port;


/// 会话连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
/// 会话断开连接
- (void)disconnect;
- (void)forceDisconnect;


/// 网络断开
- (void)networkDidBecomeAvailable;
/// 网络恢复
- (void)networkDidBecomeUnavailable;


/// 发送消息
- (void)sendData:(NSData *)data;



/// 发送心跳包
- (void)sendHeartbeat:(NSData *)heartbeatData;
/// 更新连接状态
- (void)updateConnectionState:(TJPConnectState)state;
/// 断开连接原因
- (void)disconnectWithReason:(TJPDisconnectReason)reason;
/// 准备重连
- (void)forceReconnect;
/// 清理资源方法
- (void)prepareForRelease;


@end

NS_ASSUME_NONNULL_END
