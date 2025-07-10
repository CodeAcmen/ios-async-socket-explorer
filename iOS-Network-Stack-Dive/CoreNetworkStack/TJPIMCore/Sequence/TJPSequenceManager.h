//
//  TJPSequenceManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//  序列号管理器

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 序列号管理器
 *
 * 设计说明：
 * - 32位序列号 = 8位类别 + 24位序列号
 * - 支持4种消息类别，每种独立计数
 * - 线程安全，使用 os_unfair_lock
 * - 会话级隔离，避免不同会话序列号冲突
 * - 提前重置机制，避免序列号溢出
 */

@interface TJPSequenceManager : NSObject

/// 关联的会话ID（只读）
@property (nonatomic, copy, readonly) NSString *sessionId;


/// 序列号重置回调
@property (nonatomic, copy) void (^sequenceResetHandler)(TJPMessageCategory category);

/// 初始化方法
- (instancetype)initWithSessionId:(nullable NSString *)sessionId;

/// 根据类型获取下个序列号
- (uint32_t)nextSequenceForCategory:(TJPMessageCategory)category;
/// 检查是否为该类别的序列号
- (BOOL)isSequenceForCategory:(uint32_t)sequence category:(TJPMessageCategory)category;
/// 获取指定类别的当前序列号
- (uint32_t)currentSequenceForCategory:(TJPMessageCategory)category;
/// 获取指定类别的原始序列号
- (uint32_t)currentRawSequenceForCategory:(TJPMessageCategory)category;

/// 重置序列号
- (void)resetSequence;
/// 重置当前类别序列号
- (void)resetSequence:(TJPMessageCategory)category;
/// 检查指定类别的序列号是否在安全范围内
- (BOOL)isSequenceInSafeRange:(TJPMessageCategory)category;

/// 获取详细统计信息
- (NSDictionary *)getStatistics;

/// 健康检查
- (BOOL)isHealthy;

/// 预测指定类别下次重置的时间
- (NSTimeInterval)estimateTimeToResetForCategory:(TJPMessageCategory)category averageQPS:(double)qps;

@end

NS_ASSUME_NONNULL_END
