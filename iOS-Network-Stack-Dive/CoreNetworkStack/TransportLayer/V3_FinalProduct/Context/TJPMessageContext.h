//
//  TJPMessageContext.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  消息上下文

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageContext : NSObject

/// 序列号
@property (nonatomic, assign) uint32_t sequence;
/// 发送时间
@property (nonatomic, strong) NSDate *sendTime;
/// 重试次数
@property (nonatomic, assign) NSInteger retryCount;



+ (instancetype)contextWithData:(NSData *)data;
- (NSData *)buildRetryPacket;

@end

NS_ASSUME_NONNULL_END
