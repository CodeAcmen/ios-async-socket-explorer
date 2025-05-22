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

/// 序列号
@property (nonatomic, assign) uint32_t sequence;
/// 发送时间
@property (nonatomic, strong) NSDate *sendTime;
/// 重试次数
@property (nonatomic, assign) NSInteger retryCount;
/// 加密类型
@property (nonatomic, assign) TJPEncryptType encryptType;
/// 压缩类型
@property (nonatomic, assign) TJPCompressType compressType;
/// 会话ID
@property (nonatomic, copy) NSString *sessionId;
/// 消息类型
@property (nonatomic, assign) TJPMessageType messageType;
/// 最大重试次数
@property (nonatomic, assign) NSInteger maxRetryCount;
/// 重试超时时间(秒)
@property (nonatomic, assign) NSTimeInterval retryTimeout;



+ (instancetype)contextWithData:(NSData *)data seq:(uint32_t)seq messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionId:(NSString *)sessionId;

//构建重传包
- (NSData *)buildRetryPacket;
//是否重传
- (BOOL)shouldRetry;
- (NSTimeInterval)timeElapsedSinceLastSend;

@end

NS_ASSUME_NONNULL_END
