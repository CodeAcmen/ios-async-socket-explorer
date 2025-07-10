//
//  TJPMessageTimeoutManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TJPChatMessage;

@interface TJPMessageTimeoutManager : NSObject

// 存储所有正在发送的消息
@property (nonatomic, strong) NSMutableArray<TJPChatMessage *> *pendingMessages;
// 统一处理定时器
@property (nonatomic, strong) dispatch_source_t timeoutTimer;

+ (instancetype)sharedManager;
- (void)addMessageForTimeoutCheck:(TJPChatMessage *)message;
- (void)removeMessageFromTimeoutCheck:(TJPChatMessage *)message;
// 定时检查消息超时
- (void)checkMessagesTimeout;

@end

NS_ASSUME_NONNULL_END
