//
//  TJPMessageContext.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  消息上下文 用于记录相关元数据

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageContext : NSObject

//基本信息
/// 消息唯一ID
@property (nonatomic, copy) NSString *messageId;
/// 会话ID
@property (nonatomic, copy) NSString *sessionId;
/// 消息类型
@property (nonatomic, assign) TJPMessageType messageType;
/// 消息状态
@property (nonatomic, assign) TJPMessageState state;
/// 消息内容
@property (nonatomic, strong, readonly) NSData *payload;
/// 消息优先级
@property (nonatomic, assign) TJPMessagePriority priority;
/// 加密类型
@property (nonatomic, assign) TJPEncryptType encryptType;
/// 压缩类型
@property (nonatomic, assign) TJPCompressType compressType;


//网络相关
/// 序列号
@property (nonatomic, assign) uint32_t sequence;


//时间信息
/// 发送时间
@property (nonatomic, strong) NSDate *sendTime;
/// 创建时间
@property (nonatomic, strong) NSDate *createTime;
/// 送达时间
@property (nonatomic, strong) NSDate *deliveredTime;
/// 已读时间
@property (nonatomic, strong) NSDate *readTime;
/// 最后重试时间
@property (nonatomic, strong) NSDate *lastRetryTime;


//重试信息
/// 重试次数
@property (nonatomic, assign) NSInteger retryCount;
/// 最大重试次数
@property (nonatomic, assign) NSInteger maxRetryCount;
/// 重试超时时间(秒)
@property (nonatomic, assign) NSTimeInterval retryTimeout;
/// 最后错误信息
@property (nonatomic, strong) NSError *lastError;      

/// 工厂创建方法
+ (instancetype)contextWithData:(NSData *)data seq:(uint32_t)seq messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionId:(NSString *)sessionId;

//状态查询方法
- (BOOL)isInProgress;
- (BOOL)isCompleted;
- (BOOL)canRetry;
- (NSTimeInterval)timeElapsed;

- (BOOL)isWaitingForAck;
- (BOOL)needsRetransmission;
- (NSString *)stateDisplayString;

//构建重传包
- (NSData *)buildRetryPacket;
//是否重传
- (BOOL)shouldRetry;
//计算经过时间
- (NSTimeInterval)timeElapsedSinceLastSend;

@end

NS_ASSUME_NONNULL_END
