//
//  SocketChatClient.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//  基于TCP的文本聊天客户端

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SocketChatClient : NSObject

- (void)connectToHost:(NSString *)host port:(uint16_t)port;
- (void)sendMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
