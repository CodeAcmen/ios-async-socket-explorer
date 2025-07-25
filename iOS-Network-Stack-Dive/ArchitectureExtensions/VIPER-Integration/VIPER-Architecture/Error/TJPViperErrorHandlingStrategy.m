//
//  TJPViperErrorHandlingStrategy.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
// 

#import "TJPViperErrorHandlingStrategy.h"


NSString * const TJPViperErrorDomain = @"com.tjp.viper.error";
NSString * const TJPViperErrorUserInfoKeyRetryable = @"TJPViperErrorRetryable";
NSString * const TJPViperErrorUserInfoKeyRecoverySuggestion = @"TJPViperErrorRecoverySuggestion";

@implementation TJPViperErrorHandlingStrategy

+ (instancetype)strategyForViperError:(TJPViperError)errorCode {
    TJPViperErrorHandlingStrategy *strategy = [[TJPViperErrorHandlingStrategy alloc] init];
    
    // 默认值
    strategy.shouldRetry = NO;
    strategy.maxRetryCount = 0;
    strategy.retryDelay = 1.0;
    strategy.severity = TJPViperErrorSeverityError;
    strategy.needsSpecialHandling = NO;
    
    switch (errorCode) {
        case TJPViperErrorNone:
            strategy.severity = TJPViperErrorSeverityInfo;
            strategy.userMessage = @"操作成功";
            strategy.actionTitle = @"确定";
            break;
            
        case TJPViperErrorCancelled:
            strategy.severity = TJPViperErrorSeverityInfo;
            strategy.userMessage = @"操作已取消";
            strategy.actionTitle = @"确定";
            break;
            
        case TJPViperErrorTimeout:
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 2;
            strategy.retryDelay = 2.0;
            strategy.userMessage = @"操作超时，请重试";
            strategy.actionTitle = @"重试";
            break;
            
        case TJPViperErrorDataEmpty:
            strategy.severity = TJPViperErrorSeverityWarning;
            strategy.userMessage = @"暂无数据";
            strategy.actionTitle = @"刷新";
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 1;
            break;
            
        case TJPViperErrorDataInvalid:
        case TJPViperErrorDataProcessFailed:
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 1;
            strategy.userMessage = @"数据处理失败，请重试";
            strategy.actionTitle = @"重试";
            break;
            
        case TJPViperErrorDataCacheCorrupted:
            strategy.userMessage = @"缓存数据损坏，将重新加载";
            strategy.actionTitle = @"确定";
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 1;
            break;
            
        case TJPViperErrorUserNotLogin:
            strategy.severity = TJPViperErrorSeverityCritical;
            strategy.userMessage = @"请先登录";
            strategy.actionTitle = @"去登录";
            strategy.needsSpecialHandling = YES;
            break;
            
        case TJPViperErrorUserBlocked:
            strategy.severity = TJPViperErrorSeverityCritical;
            strategy.userMessage = @"账号已被封禁，请联系客服";
            strategy.actionTitle = @"联系客服";
            strategy.needsSpecialHandling = YES;
            break;
            
        case TJPViperErrorPermissionDenied:
            strategy.userMessage = @"没有权限执行此操作";
            strategy.actionTitle = @"确定";
            break;
            
        case TJPViperErrorNavigationFailed:
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 1;
            strategy.userMessage = @"页面跳转失败";
            strategy.actionTitle = @"重试";
            break;
            
        case TJPViperErrorMemoryLow:
            strategy.severity = TJPViperErrorSeverityWarning;
            strategy.userMessage = @"设备内存不足，请清理后台应用";
            strategy.actionTitle = @"确定";
            break;
            
        case TJPViperErrorStorageFull:
            strategy.severity = TJPViperErrorSeverityWarning;
            strategy.userMessage = @"存储空间不足，请清理设备存储";
            strategy.actionTitle = @"确定";
            break;
            
        default:
            strategy.userMessage = @"操作失败，请重试";
            strategy.actionTitle = @"重试";
            strategy.shouldRetry = YES;
            strategy.maxRetryCount = 1;
            break;
    }
    
    return strategy;
}

@end
