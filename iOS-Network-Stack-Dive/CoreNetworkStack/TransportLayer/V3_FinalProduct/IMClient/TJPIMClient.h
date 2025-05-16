//
//  TJPIMClient.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import <Foundation/Foundation.h>
#import "TJPMessageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPIMClient : NSObject

/// 单例类
+ (instancetype)shared;

/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;

/// 发送消息  消息类型详见 TJPCoreTypes 头文件定义的 TJPContentType
- (void)sendMessage:(id<TJPMessageProtocol>)message;

/// 断开连接
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
