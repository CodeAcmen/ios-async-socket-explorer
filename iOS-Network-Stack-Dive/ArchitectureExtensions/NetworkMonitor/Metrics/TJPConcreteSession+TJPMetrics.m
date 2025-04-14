//
//  TJPConcreteSession+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/10.
//

#import "TJPConcreteSession+TJPMetrics.h"
#import <GCDAsyncSocket.h>
#import <objc/runtime.h>

#import "TJPMetricsCollector.h"


@implementation TJPConcreteSession (TJPMetrics)
+ (void)initialize {
    [self enableMetricsMonitoring];
}

+ (void)enableMetricsMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleMethod:@selector(sendData:)
                withMethod:@selector(metrics_sendData:)];
        
        [self swizzleMethod:@selector(socket:didReadData:withTag:)
                withMethod:@selector(metrics_socket:didReadData:withTag:)];
        
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

// 埋点发送消息方法
- (void)metrics_sendData:(NSData *)data {
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyBytesSend by:data.length];
    [self metrics_sendData:data];
}

// 埋点接收消息方法
- (void)metrics_socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyBytesReceived by:data.length];
    [self metrics_socket:sock didReadData:data withTag:tag];
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





