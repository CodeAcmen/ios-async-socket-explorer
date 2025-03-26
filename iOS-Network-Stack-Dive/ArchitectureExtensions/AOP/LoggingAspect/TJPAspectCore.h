//
//  TJPAspectCore.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//  核心类

#import <Foundation/Foundation.h>
#import "TJPLogAspectInterface.h"

@class TJPLogModel;
NS_ASSUME_NONNULL_BEGIN

@interface TJPAspectCore : NSObject

/// 注册日志切面
+ (void)registerLogWithConfig:(TJPLogConfig)config trigger:(TJPLogTriggerPoint)trigger handler:(void(^)(TJPLogModel *log))handler;

/// 移除日志切面
+ (void)removeLogForClass:(Class)cls;
@end

NS_ASSUME_NONNULL_END
