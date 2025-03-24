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
/// 每个会话会有独立的id
@property (nonatomic, copy, readonly) NSString *sessionId;

/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
/// 发送消息
- (void)sendData:(NSData *)data;
/// 断开连接原因
- (void)disconnectWithReason:(TJPDisconnectReason)reason;


@end

NS_ASSUME_NONNULL_END
