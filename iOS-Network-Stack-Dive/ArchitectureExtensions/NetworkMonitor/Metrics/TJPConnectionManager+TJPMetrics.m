//
//  TJPConnectionManager+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/15.
//

#import "TJPConnectionManager+TJPMetrics.h"
#import <GCDAsyncSocket.h>
#import <objc/runtime.h>

#import "TJPMetricsCollector.h"


@implementation TJPConnectionManager (TJPMetrics)
+ (void)initialize {
    [self enableMetricsMonitoring];
}

+ (void)enableMetricsMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        [self swizzleMethod:@selector(connectToHost:port:)
                withMethod:@selector(metrics_connectToHost:port:)];
        
        [self swizzleMethod:@selector(socket:didConnectToHost:port:)
                 withMethod:@selector(metrics_socket:didConnectToHost:port:)];
    });
}

+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector {
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(self,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(self,
                          swizzledSelector,
                          method_getImplementation(originalMethod),
                          method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}


// 埋点连接方法
- (void)metrics_connectToHost:(NSString *)host port:(uint16_t)port{
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyConnectionAttempts];
    [self metrics_connectToHost:host port:port];
}

// 连接成功方法
- (void)metrics_socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyConnectionSuccess];
    [self metrics_socket:sock didConnectToHost:host port:port];
}
@end
