//
//  TJPLoggerManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import <Foundation/Foundation.h>
#import "TJPLogAspectInterface.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TJPLogOutputOption) {
    TJPLogOutputOptionNone        = 0,
    TJPLogOutputOptionConsole     = 1 << 0, // 控制台日志
    TJPLogOutputOptionFile        = 1 << 1, // 文件日志
    TJPLogOutputOptionServer      = 1 << 2  // 上传服务器
};

@interface TJPLoggerManager : NSObject


/// 注册日志切面的方法
+ (void)registerLogForTargetClass:(Class)targetClass targetSelector:(SEL)targetSelector triggers:(TJPLogTriggerPoint)triggers outputs:(TJPLogOutputOption)outputOption;


/// 移除切面日志
+ (void)removeLogForTargetClass:(Class)targetClass;

@end

NS_ASSUME_NONNULL_END
