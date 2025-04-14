//
//  TJPMetricsConsoleReporter.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import "TJPMetricsConsoleReporter.h"
#import <os/lock.h>

#import "TJPMetricsCollector.h"

static os_unfair_lock _reportLock = OS_UNFAIR_LOCK_INIT;
static dispatch_source_t _timer;
static BOOL _isRunning = NO;

@implementation TJPMetricsConsoleReporter

+ (BOOL)isRunning {
    return _isRunning;
}


+ (void)start {
    [self startWithInterval:15.0];
}

+ (void)startWithInterval:(NSTimeInterval)interval {
    if (_isRunning) return;
    
    _isRunning = YES;
    
    dispatch_queue_t queue = dispatch_queue_create("com.tjp.network.monitor.queue", 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, interval * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(_timer, ^{
        [self printMetrics];
    });
    
    dispatch_resume(_timer);
    
    NSLog(@"开始执行指标打印");
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
    NSLog(@"指标打印停止");

}

+ (void)flush {
    [self printMetrics];
}

#pragma mark - 核心输出逻辑
+ (void)printMetrics {
    os_unfair_lock_lock(&_reportLock);
    
    TJPMetricsCollector *collector = [TJPMetricsCollector sharedInstance];
    
    // 1. 时间戳
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // 2. 构建中文报告
    NSMutableString *report = [NSMutableString stringWithFormat:@"\n网络指标报告 时间 - %@\n", timestamp];
    
    // 3. 连接指标
    [report appendFormat:@"\n[连接状态]\n  尝试次数: %lu\n  成功次数: %lu (成功率: %.1f%%)\n",
     [collector counterValue:TJPMetricsKeyConnectionAttempts],
     [collector counterValue:TJPMetricsKeyConnectionSuccess],
     [collector connectSuccessRate] * 100];
    
    // 4. 流量统计
    [report appendFormat:@"\n[流量统计]\n  发送数据: %.2f KB\n  接收数据: %.2f KB\n",
         [collector counterValue:TJPMetricsKeyBytesSend] / 1024.0,
         [collector counterValue:TJPMetricsKeyBytesReceived] / 1024.0];

    
    // 5. 心跳数据
    [report appendFormat:@"\n[心跳检测]\n  发送心跳: %lu 次\n  丢失心跳: %lu 次 (丢包率: %.1f%%)\n 平均RTT: %.1fms\n",
     [collector counterValue:TJPMetricsKeyHeartbeatSend],
     [collector counterValue:TJPMetricsKeyHeartbeatLoss],
     [collector packetLossRate] * 100,
    [collector averageRTT] * 1000];
    

    
    // 6. 网络质量
    [report appendFormat:@"\n[网络质量]\n  平均往返时间: %.1fms\n",
     [collector averageRTT] * 1000];
    
    printf("%s\n", report.UTF8String);
    
    os_unfair_lock_unlock(&_reportLock);
}



@end




