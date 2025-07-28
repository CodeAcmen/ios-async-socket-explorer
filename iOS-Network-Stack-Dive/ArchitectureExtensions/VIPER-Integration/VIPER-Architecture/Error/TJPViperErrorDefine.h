//
//  TJPViperErrorDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/10.
//


#ifndef TJPErrorUtil_h
#define TJPErrorUtil_h

#import <Foundation/Foundation.h>

/**
 * VIPER应用层错误代码枚举
 * 错误域: "com.tjp.viper.error"
 *
 * 注意：这是应用层错误，与底层网络框架的TJPNetworkError分离
 */
typedef NS_ENUM(NSInteger, TJPViperError) {
    // 基础错误 (0-99)
    TJPViperErrorNone                    = 0,    // 无错误
    TJPViperErrorUnknown                 = 1,    // 未知错误
    TJPViperErrorCancelled               = 2,    // 用户取消操作
    TJPViperErrorTimeout                 = 3,    // 应用层操作超时
    
    // 数据相关错误 (100-199)
    TJPViperErrorDataEmpty               = 100,  // 数据为空
    TJPViperErrorDataInvalid             = 101,  // 数据格式无效
    TJPViperErrorDataProcessFailed       = 102,  // 数据处理失败
    TJPViperErrorDataCacheCorrupted      = 103,  // 缓存数据损坏
    
    // 业务逻辑错误 (200-299)
    TJPViperErrorBusinessLogicFailed     = 200,  // 业务逻辑失败
    TJPViperErrorPermissionDenied        = 201,  // 权限不足
    TJPViperErrorUserNotLogin            = 202,  // 用户未登录
    TJPViperErrorUserBlocked             = 203,  // 用户被封禁
    TJPViperErrorOperationNotSupported   = 204,  // 操作不支持
    
    // UI交互错误 (300-399)
    TJPViperErrorViewNotReady            = 300,  // 视图未准备好
    TJPViperErrorNavigationFailed        = 301,  // 页面导航失败
    TJPViperErrorPresenterNotBound       = 302,  // Presenter未绑定
    
    // 系统资源错误 (400-499)
    TJPViperErrorMemoryLow              = 400,   // 内存不足
    TJPViperErrorStorageFull            = 401,   // 存储空间不足
    TJPViperErrorDeviceNotSupported     = 402,   // 设备不支持
};

/**
 * 错误严重程度
 */
typedef NS_ENUM(NSUInteger, TJPViperErrorSeverity) {
    TJPViperErrorSeverityInfo = 0,      // 信息提示
    TJPViperErrorSeverityWarning,       // 警告
    TJPViperErrorSeverityError,         // 错误
    TJPViperErrorSeverityCritical       // 严重错误
};

// VIPER错误域常量
FOUNDATION_EXPORT NSString * const TJPViperErrorDomain;

// 错误信息键
FOUNDATION_EXPORT NSString * const TJPViperErrorUserInfoKeyRetryable;
FOUNDATION_EXPORT NSString * const TJPViperErrorUserInfoKeyRecoverySuggestion;



#endif /* TJPErrorUtil_h */
