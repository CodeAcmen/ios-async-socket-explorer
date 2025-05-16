//
//  TJPMetricsConsoleReporter.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//  控制台输出

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPNetworkConfig;

@interface TJPMetricsConsoleReporter : NSObject

/**
 * 报告回调，用于自定义报告处理
 */
@property (nonatomic, copy, nullable) void (^reportCallback)(NSString *report);

/**
 * 是否正在运行
 */
@property (nonatomic, class, readonly) BOOL isRunning;

/**
 * 当前指标收集级别
 */
@property (nonatomic, class, readonly) TJPMetricsLevel currentLevel;

/**
 * 获取单例实例
 */
+ (instancetype)sharedInstance;

/**
 * 启动控制台输出 默认15s间隔，标准级别
 */
+ (void)start;

/**
 * 自定义时间间隔启动控制台输出，标准级别
 * @param interval 报告输出间隔（秒）
 */
+ (void)startWithInterval:(NSTimeInterval)interval;

/**
 * 使用指定级别启动指标收集
 * @param level 指标收集级别
 */
+ (void)startWithLevel:(TJPMetricsLevel)level;

/**
 * 使用配置启动指标收集
 * @param config 网络配置
 */
+ (void)startWithConfig:(TJPNetworkConfig *)config;

/**
 * 使用完整配置启动指标收集
 * @param level 指标收集级别
 * @param consoleEnabled 是否在控制台输出
 * @param interval 报告间隔（秒）
 */
+ (void)startWithLevel:(TJPMetricsLevel)level
        consoleEnabled:(BOOL)consoleEnabled
              interval:(NSTimeInterval)interval;

/**
 * 停止指标收集
 */
+ (void)stop;

/**
 * 立即触发一次报告生成和输出
 */
+ (void)flush;

/**
 * 生成当前指标报告
 * @return 指标报告字符串
 */
+ (NSString *)generateReport;

/**
 * 将指标级别转为可读字符串
 * @param level 指标级别
 * @return 级别对应的字符串描述
 */
+ (NSString *)metricsLevelToString:(TJPMetricsLevel)level;



@end

NS_ASSUME_NONNULL_END
