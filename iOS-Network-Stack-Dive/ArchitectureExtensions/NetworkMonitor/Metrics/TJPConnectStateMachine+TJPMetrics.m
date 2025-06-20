//
//  TJPConnectStateMachine+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import "TJPConnectStateMachine+TJPMetrics.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "TJPMetricsCollector.h"

@implementation TJPConnectStateMachine (TJPMetrics)


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleSendEvent];
        [self swizzleStateSetter];
    });
}

+ (void)swizzleSendEvent {
    Class class = [self class];
    
    //Hook sendEvent方法
    SEL originSEL = @selector(sendEvent:);
    SEL swizzleSEL = @selector(metrics_sendEvent:);
    
    Method originMethod = class_getInstanceMethod(class, originSEL);
    Method swizzleMethod = class_getInstanceMethod(class, swizzleSEL);
    
    // 检查原始方法是否存在
    if (!originMethod || !swizzleMethod) {
        NSLog(@"Method not found!");
        return;
    }
    
    method_exchangeImplementations(originMethod, swizzleMethod);
}

+ (void)swizzleStateSetter {
    //Hook 系统隐式生成的setter方法
    SEL setterSEL = NSSelectorFromString(@"setCurrentState:");
    if (!setterSEL) return;
    
    Class class = [self class];
    
    if (!class_respondsToSelector(class, setterSEL)) { // 关键检查
        NSLog(@"setCurrentState: not found!");
        return;
    }
    
    SEL originSEL = setterSEL;
    SEL swizzleSEL = @selector(metrics_setCurrentState:);
    
    Method originMethod = class_getInstanceMethod(class, originSEL);
    Method swizzleMethod = class_getInstanceMethod(class, swizzleSEL);
    
    method_exchangeImplementations(originMethod, swizzleMethod);
}



#pragma mark - Swizzled Method
- (void)metrics_sendEvent:(TJPConnectEvent)event {
    //记录开始时间
    NSTimeInterval startTime = CACurrentMediaTime();
    
    //调用原始实现
    [self metrics_sendEvent:event];
    
    //记录事件处理耗时
    NSTimeInterval duration = CACurrentMediaTime() - startTime;
    [[TJPMetricsCollector sharedInstance] addTimeSample:duration forKey:[NSString stringWithFormat:@"event_%@", event]];
}


- (void)metrics_setCurrentState:(TJPConnectState)newState {
    if (self.isInitializing) {
        NSLog(@"[METRICS] 初始化期间，直接设置状态: %@", newState);
        // 直接调用原始方法，不进行指标收集
        [self metrics_setCurrentState:newState];
        return;
    }
    if (self.metrics_stateEnterTime == 0) {
        NSLog(@"[METRICS] 首次启动指标收集，状态: %@", newState);
        self.metrics_stateEnterTime = CACurrentMediaTime();
        [self metrics_setCurrentState:newState];
        return;
    }
    
    // 递归保护
    static NSMutableSet *processingInstances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processingInstances = [NSMutableSet set];
    });
    
    @synchronized(processingInstances) {
        NSString *instanceKey = [NSString stringWithFormat:@"%p", self];
        if ([processingInstances containsObject:instanceKey]) {
            NSLog(@"[METRICS] 检测到递归调用，跳过指标收集");
            [self metrics_setCurrentState:newState];
            return;
        }
        [processingInstances addObject:instanceKey];
    }
    
    @try {
        // 记录旧状态的进入时间
        NSTimeInterval previousEnterTime = self.metrics_stateEnterTime;
           
        // 立即更新进入时间到当前时间（新状态的开始时间）
        self.metrics_stateEnterTime = CACurrentMediaTime();
        
        // 获取旧状态并计算持续时间
        TJPConnectState oldState = self.currentState;
        NSTimeInterval duration = self.metrics_stateEnterTime - previousEnterTime;
        
        // 首次设置状态时，oldState 为 nil，不记录
        if (oldState && duration > 0 && ![oldState isEqualToString:newState]) {
            NSString *key = [NSString stringWithFormat:@"state_%@", oldState];
            
            NSLog(@"[METRICS] 状态变化: %@ -> %@, 持续时间: %.3f秒", oldState, newState, duration);

            [[TJPMetricsCollector sharedInstance] addTimeSample:duration forKey:key];
        }
        
        // 调用原始实现（更新 currentState）
        [self metrics_setCurrentState:newState];
    } @finally {
        // 清理递归标记
        @synchronized(processingInstances) {
            NSString *instanceKey = [NSString stringWithFormat:@"%p", self];
            [processingInstances removeObject:instanceKey];
        }
    }
}

#pragma mark - Associated Properties
- (NSTimeInterval)metrics_stateEnterTime {
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
}

- (void)setMetrics_stateEnterTime:(NSTimeInterval)metrics_stateEnterTime {
    objc_setAssociatedObject(self, @selector(metrics_stateEnterTime), @(metrics_stateEnterTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end
