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

@property (nonatomic, readonly) TJPConnectState connectState;

/// 每个会话会有独立的id  使用UUID保证唯一
@property (nonatomic, copy, readonly) NSString *sessionId;

/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
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
/// 重连方法
- (void)triggerAutoReconnectIfNeeded;
/// 清理资源方法
- (void)prepareForRelease;


@end

NS_ASSUME_NONNULL_END
