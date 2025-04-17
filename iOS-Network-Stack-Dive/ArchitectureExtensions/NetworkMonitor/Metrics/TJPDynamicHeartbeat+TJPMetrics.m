//
//  TJPDynamicHeartbeat+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/11.
//

#import "TJPDynamicHeartbeat+TJPMetrics.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "TJPMetricsCollector.h"

@implementation TJPDynamicHeartbeat (TJPMetrics)


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleHeartbeatMethods];
    });
}

#pragma mark - Method Swizzling
+ (void)swizzleHeartbeatMethods {    
    // 发送心跳埋点
    [self swizzleSelector:@selector(sendHeartbeat)
              withSelector:@selector(metrics_sendHeartbeat)];
    
    [self swizzleSelector:@selector(sendHeartbeatFailed)
             withSelector:@selector(metrics_sendHeartbeatFailed)];

    
    // ACK处理埋点
    [self swizzleSelector:@selector(heartbeatACKNowledgedForSequence:)
              withSelector:@selector(metrics_heartbeatACKNowledgedForSequence:)];
    
    // 超时处理埋点
    [self swizzleSelector:@selector(handleHeaderbeatTimeoutForSequence:)
              withSelector:@selector(metrics_handleHeaderbeatTimeoutForSequence:)];
}

+ (void)swizzleSelector:(SEL)original withSelector:(SEL)swizzled {
    Class cls = [self class];
    Method originalMethod = class_getInstanceMethod(cls, original);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzled);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

#pragma mark - Swizzled Methods
- (void)metrics_sendHeartbeat {
    // 埋点记录
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyHeartbeatSend];
    [[TJPMetricsCollector sharedInstance] addValue:self.currentInterval forKey:TJPMetricsKeyHeartbeatInterval];
    // 调用原始方法
    [self metrics_sendHeartbeat];
}

- (void)metrics_sendHeartbeatFailed {
    // 埋点记录
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyHeartbeatLoss];
    [[TJPMetricsCollector sharedInstance] addValue:self.currentInterval forKey:TJPMetricsKeyHeartbeatTimeoutInterval];

    // 调用原始方法
    [self metrics_sendHeartbeatFailed];
}

- (void)metrics_heartbeatACKNowledgedForSequence:(uint32_t)sequence {
    NSDate *sendTime = self.pendingHeartbeats[@(sequence)];
    if (sendTime) {
        // 计算RTT（毫秒级精度）
        NSTimeInterval rtt = [[NSDate date] timeIntervalSinceDate:sendTime] * 1000;
        
        // 记录关键指标
        [[TJPMetricsCollector sharedInstance] addTimeSample:rtt/1000.0 forKey:TJPMetricsKeyRTT];
        [[TJPMetricsCollector sharedInstance] addValue:rtt forKey:TJPMetricsKeyHeartbeatRTT];
    }
    
    // 调用原始方法
    [self metrics_heartbeatACKNowledgedForSequence:sequence];
}

- (void)metrics_handleHeaderbeatTimeoutForSequence:(uint32_t)sequence {
    // 记录丢包事件
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyHeartbeatLoss];
    [[TJPMetricsCollector sharedInstance] addValue:self.currentInterval forKey:TJPMetricsKeyHeartbeatTimeoutInterval];
    
    // 调用原始方法
    [self metrics_handleHeaderbeatTimeoutForSequence:sequence];
}

#pragma mark - Computed Properties
- (float)heartbeatLossRate {
    NSUInteger sent = [[TJPMetricsCollector sharedInstance] counterValue:TJPMetricsKeyHeartbeatSend];
    NSUInteger lost = [[TJPMetricsCollector sharedInstance] counterValue:TJPMetricsKeyHeartbeatLoss];
    return (sent > 0) ? (float)lost/(float)sent : 0;
}

- (NSTimeInterval)avgRTT {
    return [[TJPMetricsCollector sharedInstance] averageDuration:TJPMetricsKeyRTT];
}

@end



