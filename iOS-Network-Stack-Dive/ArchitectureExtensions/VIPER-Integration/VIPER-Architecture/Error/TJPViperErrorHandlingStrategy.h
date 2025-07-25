//
//  TJPViperErrorHandlingStrategy.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
//  VIPER应用层错误处理策略

#import <Foundation/Foundation.h>
#import "TJPViperErrorDefine.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPViperErrorHandlingStrategy : NSObject

/// 是否可以重试
@property (nonatomic, assign) BOOL shouldRetry;

/// 最大重试次数
@property (nonatomic, assign) NSInteger maxRetryCount;

/// 重试延迟时间(秒)
@property (nonatomic, assign) NSTimeInterval retryDelay;

/// 用户友好的错误描述
@property (nonatomic, copy) NSString *userMessage;

/// 操作按钮标题
@property (nonatomic, copy) NSString *actionTitle;

/// 错误严重程度
@property (nonatomic, assign) TJPViperErrorSeverity severity;

/// 恢复建议
@property (nonatomic, copy, nullable) NSString *recoverySuggestion;

/// 是否需要特殊处理
@property (nonatomic, assign) BOOL needsSpecialHandling;

/**
 * 根据TJPViperError创建处理策略
 */
+ (instancetype)strategyForViperError:(TJPViperError)errorCode;

@end

NS_ASSUME_NONNULL_END
