//
//  TJPViperDefaultErrorHandler.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
//  默认VIPER错误处理器

#import <Foundation/Foundation.h>
#import "TJPViperErrorHandlerProtocol.h"
#import "TJPViperErrorHandlerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPViperDefaultErrorHandler : NSObject <TJPViperErrorHandlerProtocol>

/// 委托对象
@property (nonatomic, weak) id<TJPViperErrorHandlerDelegate> delegate;

/// 重试计数映射表
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *retryCountMap;

/// 是否显示Debug信息
@property (nonatomic, assign) BOOL showDebugInfo;

/// 单例
+ (instancetype)sharedHandler;

@end

NS_ASSUME_NONNULL_END
