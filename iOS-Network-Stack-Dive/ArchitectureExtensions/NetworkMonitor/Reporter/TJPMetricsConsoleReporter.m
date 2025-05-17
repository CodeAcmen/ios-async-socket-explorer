//
//  TJPMetricsConsoleReporter.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import "TJPMetricsConsoleReporter.h"
#import <os/lock.h>

#import "TJPMetricsCollector.h"
#import "TJPNetworkConfig.h"
#import "TJPNetworkDefine.h"


// 静态变量
static os_unfair_lock _reportLock = OS_UNFAIR_LOCK_INIT;
static dispatch_source_t _timer;
static BOOL _isRunning = NO;
static TJPMetricsLevel _currentLevel = TJPMetricsLevelStandard;
static BOOL _consoleEnabled = YES;
static NSTimeInterval _reportInterval = 15.0;


@implementation TJPMetricsConsoleReporter

#pragma mark - Init
+ (instancetype)sharedInstance {
    static TJPMetricsConsoleReporter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPMetricsConsoleReporter alloc] init];
    });
    return instance;
}

- (void)dealloc {
    TJPLogDealloc();
}



#pragma mark - Private Method
+ (BOOL)isRunning {
    return _isRunning;
}

+ (TJPMetricsLevel)currentLevel {
    return _currentLevel;
}


#pragma markdown - Public Method
+ (void)start {
    [self startWithLevel:TJPMetricsLevelStandard consoleEnabled:YES interval:15.0];
}

+ (void)startWithInterval:(NSTimeInterval)interval {
    [self startWithLevel:TJPMetricsLevelStandard consoleEnabled:YES interval:interval];
}

+ (void)startWithLevel:(TJPMetricsLevel)level {
    [self startWithLevel:level consoleEnabled:YES interval:15.0];
}

+ (void)startWithConfig:(TJPNetworkConfig *)config {
    [self startWithLevel:config.metricsLevel consoleEnabled:config.metricsConsoleEnabled interval:config.metricsReportInterval];
}

+ (void)startWithLevel:(TJPMetricsLevel)level consoleEnabled:(BOOL)consoleEnabled interval:(NSTimeInterval)interval {
    if (_isRunning) {
        // 停止已有的定时器
        [self stop];
    };
    // 如果level为None级别,直接返回
    if (level == TJPMetricsLevelNone) return;
    
    
    // 更新配置
    _currentLevel = level;
    _consoleEnabled = consoleEnabled;
    _reportInterval = interval;
    _isRunning = YES;
    
    // 创建定时器
    dispatch_queue_t queue = dispatch_queue_create("com.tjp.network.monitor.queue", DISPATCH_QUEUE_SERIAL);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, interval * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(_timer, ^{
        [self printMetrics];
    });
    
    // 启动定时器
    dispatch_resume(_timer);
    
    TJPLOG_INFO(@"开始执行指标打印 - 级别: %@", [self metricsLevelToString:_currentLevel]);
}

+ (void)stop {
    if (!_isRunning) {
        return;
    }
    
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
    
    _isRunning = NO;
    TJPLOG_INFO(@"指标打印停止");

}

+ (void)flush {
    [self printMetrics];
}

#pragma mark - Core logic
+ (void)printMetrics {
    // 生成报告
    NSString *report = [self generateReport];
    
    // 是否开启控制台打印
    if (_consoleEnabled) {
        printf("%s\n", report.UTF8String);
    }
    
    
    if ([TJPMetricsConsoleReporter sharedInstance].reportCallback) {
        [TJPMetricsConsoleReporter sharedInstance].reportCallback([report copy]);
    }
    
}

+ (NSString *)generateReport {
    os_unfair_lock_lock(&_reportLock);
    
    TJPMetricsCollector *collector = [TJPMetricsCollector sharedInstance];
    
    // 时间戳
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // 构建中文报告
    NSMutableString *report = [NSMutableString stringWithFormat:@"\n网络指标报告 时间 - %@\n", timestamp];
    
    // 连接指标  所有级别
    [report appendFormat:@"\n[连接状态]\n  尝试次数: %lu\n  成功次数: %lu (成功率: %.1f%%)\n",
     [collector counterValue:TJPMetricsKeyConnectionAttempts],
     [collector counterValue:TJPMetricsKeyConnectionSuccess],
     [collector connectSuccessRate] * 100];
    
    // 流量统计  标准级别以上
    if (_currentLevel >= TJPMetricsLevelStandard) {
        [report appendFormat:@"\n[流量统计]\n  发送数据: %.2f KB\n  接收数据: %.2f KB\n",
         [collector counterValue:TJPMetricsKeyBytesSend] / 1024.0,
         [collector counterValue:TJPMetricsKeyBytesReceived] / 1024.0];
    }
    
    
    // 心跳数据  标准级别以上
    if (_currentLevel >= TJPMetricsLevelStandard) {
        [report appendFormat:@"\n[心跳检测]\n  发送心跳: %lu 次\n  丢失心跳: %lu 次 (丢包率: %.1f%%)\n 平均RTT: %.1fms\n",
         [collector counterValue:TJPMetricsKeyHeartbeatSend],
         [collector counterValue:TJPMetricsKeyHeartbeatLoss],
         [collector packetLossRate] * 100,
         [collector averageRTT] * 1000];
        
    }
    
    
    // 网络质量  所有级别
    [report appendFormat:@"\n[网络质量]\n  平均往返时间: %.1fms\n",
     [collector averageRTT] * 1000];
    
    
    // 消息统计  详细级别以上
    if (_currentLevel >= TJPMetricsLevelStandard) {
        [report appendFormat:@"\n[消息统计]\n  发送消息: %lu 条\n  确认消息: %lu 条\n",
         (unsigned long)[collector counterValue:TJPMetricsKeyMessageSend],
         (unsigned long)[collector counterValue:TJPMetricsKeyMessageAcked]];
    }
    
    
    // 调试信息  调试级别
    if (_currentLevel >= TJPMetricsLevelDebug) {
        [report appendString:@"\n[调试信息]\n"];
        
        // 会话状态
        [report appendFormat:@"  断开次数: %lu 次\n  重连次数: %lu 次\n",
         (unsigned long)[collector counterValue:TJPMetricsKeySessionDisconnects],
         (unsigned long)[collector counterValue:TJPMetricsKeySessionReconnects]];
        
        // 错误统计
        [report appendFormat:@"  错误总数: %lu 个\n",
         (unsigned long)[collector counterValue:TJPMetricsKeyErrorCount]];
        
        // 最近错误
        NSArray *recentErrors = [collector recentErrors];
        if (recentErrors.count > 0) {
            [report appendString:@"  最近错误:\n"];
            
            // 最多显示5条最新错误
            NSInteger startIndex = MAX(0, recentErrors.count - 5);
            for (NSInteger i = startIndex; i < recentErrors.count; i++) {
                NSDictionary *error = recentErrors[i];
                NSDate *time = error[@"time"];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"HH:mm:ss";
                
                [report appendFormat:@"    %@: [%@] %@ (代码: %@)\n",
                 [formatter stringFromDate:time],
                 error[@"key"],
                 error[@"message"],
                 error[@"code"]];
            }
        }
    }
    
    os_unfair_lock_unlock(&_reportLock);
    return [report copy];
}

+ (NSString *)metricsLevelToString:(TJPMetricsLevel)level {
    switch (level) {
        case TJPMetricsLevelNone:
            return @"无";
        case TJPMetricsLevelBasic:
            return @"基本";
        case TJPMetricsLevelStandard:
            return @"标准";
        case TJPMetricsLevelDetailed:
            return @"详细";
        case TJPMetricsLevelDebug:
            return @"调试";
        default:
            return @"未知";
    }
}



@end




