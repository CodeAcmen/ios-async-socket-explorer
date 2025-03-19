//
//  SocketChatServer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//  基于TCP的文本聊天服务器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SocketChatServerDelegate <NSObject>

- (void)didReceiveMessageFromClient:(NSString *)message;

@end

@interface SocketChatServer : NSObject

@property (nonatomic, weak) id<SocketChatServerDelegate> delegate;

- (void)startServerOnPort:(uint16_t)port;
- (void)stopServer;
@end

NS_ASSUME_NONNULL_END
