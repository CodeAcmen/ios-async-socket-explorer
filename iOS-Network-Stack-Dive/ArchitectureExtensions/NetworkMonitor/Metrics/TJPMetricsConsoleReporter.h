//
//  TJPMetricsConsoleReporter.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//  控制台输出

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPMetricsConsoleReporter : NSObject

// 是否正在运行
@property (nonatomic, class, readonly) BOOL isRunning;


/// 启动控制台输出 默认15s
+ (void)start;

/// 自定义时间间隔 启动控制台输出
+ (void)startWithInterval:(NSTimeInterval)interval;

/// 停止输出
+ (void)stop;

/// 立即触发一次输出
+ (void)flush;



@end

NS_ASSUME_NONNULL_END
