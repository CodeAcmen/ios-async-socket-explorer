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
    
    // 心跳发送失败买点
    [self swizzleSelector:@selector(sendHeartbeatFailed)
             withSelector:@selector(metrics_sendHeartbeatFailed)];

    // 心跳ACK处理埋点
    [self swizzleSelector:@selector(heartbeatACKNowledgedForSequence:)
              withSelector:@selector(metrics_heartbeatACKNowledgedForSequence:)];
    
    // 心跳超时处理埋点
    [self swizzleSelector:@selector(handleHeaderbeatTimeoutForSequence:)
              withSelector:@selector(metrics_handleHeaderbeatTimeoutForSequence:)];
    
    // 心跳模式改变埋点
    [self swizzleSelector:@selector(changeToHeartbeatMode:)
             withSelector:@selector(metrics_changeToHeartbeatMode:)];

    // 开始监控埋点
    [self swizzleSelector:@selector(startMonitoring)
             withSelector:@selector(metrics_startMonitoring)];

    // 关闭监控埋点
    [self swizzleSelector:@selector(stopMonitoring)
             withSelector:@selector(metrics_stopMonitoring)];

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
    
    //新增事件记录
    [self recordHeartbeatEvent:TJPHeartbeatEventSend withParameters:nil];

    // 调用原始方法
    [self metrics_sendHeartbeat];
}

- (void)metrics_sendHeartbeatFailed {
    // 埋点记录
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyHeartbeatLoss];
    [[TJPMetricsCollector sharedInstance] addValue:self.currentInterval forKey:TJPMetricsKeyHeartbeatTimeoutInterval];
    
    // 新增事件记录，使用统一常量
    [self recordHeartbeatEvent:TJPHeartbeatEventFailed withParameters:nil];

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
        
        // 新增事件记录，使用统一常量
        [self recordHeartbeatEvent:TJPHeartbeatEventACK withParameters:@{
            TJPHeartbeatParamSequence: @(sequence),
            TJPHeartbeatParamRTT: @(rtt)
        }];
    }
    
    // 调用原始方法
    [self metrics_heartbeatACKNowledgedForSequence:sequence];
}

- (void)metrics_handleHeaderbeatTimeoutForSequence:(uint32_t)sequence {
    // 记录丢包事件
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyHeartbeatLoss];
    [[TJPMetricsCollector sharedInstance] addValue:self.currentInterval forKey:TJPMetricsKeyHeartbeatTimeoutInterval];
    
    // 新增事件记录
    [self recordHeartbeatEvent:TJPHeartbeatEventTimeout withParameters:@{
        TJPHeartbeatParamSequence: @(sequence)
    }];
    
    // 调用原始方法
    [self metrics_handleHeaderbeatTimeoutForSequence:sequence];
}

- (void)metrics_changeToHeartbeatMode:(TJPHeartbeatMode)mode {
    // 记录模式变更前的状态
    TJPHeartbeatMode oldMode = 0;
    if ([self respondsToSelector:@selector(heartbeatMode)]) {
        // 此处要通过KVC拿属性名
        NSNumber *modeNumber = [self valueForKey:@"heartbeatMode"];
        if (modeNumber) {
            oldMode = [modeNumber unsignedIntegerValue];
        }
    }
    
    // 调用原始方法
    [self metrics_changeToHeartbeatMode:mode];
    
    // 记录事件
    [self recordHeartbeatEvent:TJPHeartbeatEventModeChanged withParameters:@{
        TJPHeartbeatParamOldMode: @(oldMode),
        TJPHeartbeatParamNewMode: @(mode)
    }];
}

- (void)metrics_startMonitoring {
    // 调用原始方法
    [self metrics_startMonitoring];
    
    // 记录事件，使用统一常量
    [self recordHeartbeatEvent:TJPHeartbeatEventStarted withParameters:nil];
}

- (void)metrics_stopMonitoring {
    // 记录事件，使用统一常量
    [self recordHeartbeatEvent:TJPHeartbeatEventStopped withParameters:nil];
    
    // 调用原始方法
    [self metrics_stopMonitoring];
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

- (NSDictionary *)getHeartbeatDiagnostics {
    TJPMetricsCollector *collector = [TJPMetricsCollector sharedInstance];
    
    NSMutableDictionary *diagnostics = [NSMutableDictionary dictionary];
    
    // 基本计数器指标
    diagnostics[TJPHeartbeatDiagnosticSendCount] = @([collector counterValue:TJPMetricsKeyHeartbeatSend]);
    diagnostics[TJPHeartbeatDiagnosticLossCount] = @([collector counterValue:TJPMetricsKeyHeartbeatLoss]);
    diagnostics[TJPHeartbeatDiagnosticLossRate] = @(self.heartbeatLossRate);
    
    // RTT指标
    diagnostics[TJPHeartbeatDiagnosticAverageRTT] = @(self.avgRTT);
    diagnostics[TJPHeartbeatDiagnosticCurrentInterval] = @(self.currentInterval);
    
    // 最近事件
    if ([collector respondsToSelector:@selector(recentEventsForName:limit:)]) {
        diagnostics[TJPHeartbeatDiagnosticRecentTimeouts] = [collector recentEventsForName:TJPHeartbeatEventTimeout limit:5];
        diagnostics[TJPHeartbeatDiagnosticRecentModeChanges] = [collector recentEventsForName:TJPHeartbeatEventModeChanged limit:3];
        diagnostics[TJPHeartbeatDiagnosticRecentSends] = [collector recentEventsForName:TJPHeartbeatEventSend limit:5];
        diagnostics[TJPHeartbeatDiagnosticRecentACKs] = [collector recentEventsForName:TJPHeartbeatEventACK limit:5];
    }
    
    return diagnostics;
}

#pragma mark - Event Recording
- (void)recordHeartbeatEvent:(NSString *)eventType withParameters:(nullable NSDictionary *)params {
    // 获取公共参数
    NSMutableDictionary *eventParams = [NSMutableDictionary dictionaryWithDictionary:params ?: @{}];
    
    // 添加心跳状态作为通用参数
    eventParams[TJPHeartbeatParamInterval] = @(self.currentInterval);
    
    // 添加心跳模式
    if ([self respondsToSelector:@selector(heartbeatMode)]) {
        NSNumber *heartbeatMode = [self valueForKey:@"heartbeatMode"];
        if (heartbeatMode) {
            eventParams[TJPHeartbeatParamMode] = heartbeatMode;
        }
    }
    
    // 添加网络状态（如果可用）
    if ([self respondsToSelector:@selector(networkCondition)]) {
        id networkCondition = [self valueForKey:@"networkCondition"];
        if (networkCondition && [networkCondition respondsToSelector:NSSelectorFromString(@"qualityLevel")]) {
            NSNumber *qualityLevel = [networkCondition valueForKey:@"qualityLevel"];
            if (qualityLevel) {
                eventParams[TJPHeartbeatParamNetworkQuality] = qualityLevel;
            }
        }
    }
    
    // 记录事件
    if ([[TJPMetricsCollector sharedInstance] respondsToSelector:@selector(recordEvent:withParameters:)]) {
        [[TJPMetricsCollector sharedInstance] recordEvent:eventType withParameters:eventParams];
    }
}



@end



