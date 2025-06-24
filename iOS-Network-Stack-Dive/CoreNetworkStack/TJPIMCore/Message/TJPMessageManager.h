//
//  TJPMessageManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//  消息管理器

#import <Foundation/Foundation.h>
#import "TJPMessageManagerDelegate.h"
#import "TJPMessageManagerNetworkDelegate.h"
#import "TJPSessionProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageManager : NSObject
// 会话id
@property (nonatomic, copy, readonly) NSString *sessionId;
// 消息队列
@property (nonatomic, strong, readonly) dispatch_queue_t messageQueue;
@property (nonatomic, weak) id<TJPMessageManagerNetworkDelegate> networkDelegate;
@property (nonatomic, weak) id<TJPMessageManagerDelegate> delegate;


// 初始化方法
- (instancetype)initWithSessionId:(NSString *)sessionId;

/**
 * 创建并发送消息
 * @param messageType 消息类型
 * @param completion 回调
 */
- (NSString *)sendMessage:(NSData *)data messageType:(TJPMessageType)messageType completion:(void(^)(NSString *messageId, NSError *error))completion;

/**
 * 创建并发送消息
 * @param messageType 消息类型
 * @param encryptType 加密类型
 * @param compressType 压缩类型
 * @param completion 回调
 */
- (NSString *)sendMessage:(NSData *)data messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType completion:(void(^)(NSString *messageId, NSError *error))completion;


/// 获取消息上下文
- (TJPMessageContext *)messageWithId:(NSString *)messageId;
/// 更新消息状态
- (void)updateMessage:(NSString *)messageId toState:(TJPMessageState)newState;

/**
 * 获取所有消息
 */
- (NSArray<TJPMessageContext *> *)allMessages;

/**
 * 清理过期消息
 */
- (void)cleanupExpiredMessages;

@end

NS_ASSUME_NONNULL_END
