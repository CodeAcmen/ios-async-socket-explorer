//
//  TJPMessageTimeoutManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import "TJPMessageTimeoutManager.h"
#import "TJPChatMessage.h"
#import "TJPNetworkDefine.h"

@interface TJPMessageTimeoutManager ()

@end

@implementation TJPMessageTimeoutManager

+ (instancetype)sharedManager {
    static TJPMessageTimeoutManager *sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
        sharedManager.pendingMessages = [NSMutableArray array];
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        sharedManager.timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        dispatch_source_set_timer(sharedManager.timeoutTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 1.0 * NSEC_PER_SEC, 0);
        
        dispatch_source_set_event_handler(sharedManager.timeoutTimer, ^{
            [sharedManager checkMessagesTimeout];
        });
        dispatch_resume(sharedManager.timeoutTimer);
    });
    return sharedManager;
}

// 添加正在发送的消息到超时检查队列
- (void)addMessageForTimeoutCheck:(TJPChatMessage *)message {
    [self.pendingMessages addObject:message];
}

// 从超时检查队列中移除已经发送成功的消息
- (void)removeMessageFromTimeoutCheck:(TJPChatMessage *)message {
    if ([self.pendingMessages containsObject:message]) {
        [self.pendingMessages removeObject:message];
    }
}

// 定时检查所有正在发送的消息是否超时
- (void)checkMessagesTimeout {
    // 遍历队列中的每一条正在发送的消息
    for (TJPChatMessage *message in self.pendingMessages) {
        // 如果消息仍处于发送中状态，并且超时
        if (message.status == TJPChatMessageStatusSending && [self isTimeoutForMessage:message]) {
            // 超时处理
            message.status = TJPChatMessageStatusFailed;
            // 通知UI更新消息状态
            [[NSNotificationCenter defaultCenter] postNotificationName:kTJPMessageStatusUpdateNotification object:message];
        }
    }
}

// 判断消息是否超时
- (BOOL)isTimeoutForMessage:(TJPChatMessage *)message {
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:message.timestamp];
    return elapsedTime > 5.0; // 超过5秒视为超时
}

@end
