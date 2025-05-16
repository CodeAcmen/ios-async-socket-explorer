//
//  TJPConcreteSession+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/16.
//

#import "TJPConcreteSession+TJPMetrics.h"
#import <GCDAsyncSocket.h>
#import <objc/runtime.h>
#import "TJPMetricsCollector.h"
#import "TJPSessionProtocol.h"

@implementation TJPConcreteSession (TJPMetrics)

+ (void)initialize {
    [self enableMessageMetricsMonitoring];
}

+ (void)enableMessageMetricsMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 消息发送
        [self swizzleMethod:@selector(sendData:)
                 withMethod:@selector(metrics_sendData:)];
        
        // ack确认
        [self swizzleMethod:@selector(handleACKForSequence:)
                 withMethod:@selector(metrics_handleACKForSequence:)];
        
        // 收到消息
        [self swizzleMethod:@selector(socket:didReadData:withTag:)
                 withMethod:@selector(metrics_socket:didReadData:withTag:)];
        
        
        // 监控断开连接
        [self swizzleMethod:@selector(disconnectWithReason:)
                 withMethod:@selector(metrics_disconnectWithReason:)];
        
        // 监控重连
        [self swizzleMethod:@selector(forceReconnect)
                 withMethod:@selector(metrics_forceReconnect)];
        
        // 监控错误
        [self swizzleMethod:@selector(connection:didDisconnectWithError:reason:)
                 withMethod:@selector(metrics_connection:didDisconnectWithError:reason:)];
        
        // 监控重传
        [self swizzleMethod:@selector(handleRetransmissionForSequence:)
                withMethod:@selector(metrics_handleRetransmissionForSequence:)];
        
        // 监控版本协商
        [self swizzleMethod:@selector(performVersionHandshake)
                withMethod:@selector(metrics_performVersionHandshake)];
        
        
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

// 监控消息发送
- (void)metrics_sendData:(NSData *)data {
    // 记录消息发送
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyMessageSend];
    
    //记录发送数据量
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyBytesSend by:data.length];

    //发送普通消息
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyNormalMessageSend];
    
    // 调用原始方法
    [self metrics_sendData:data];
}

// 监控消息确认
- (void)metrics_handleACKForSequence:(uint32_t)sequence {
    // 记录消息确认
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyMessageAcked];
    
    // 调用原始方法
    [self metrics_handleACKForSequence:sequence];
}

// 埋点接收消息方法
- (void)metrics_socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyBytesReceived by:data.length];
    [self metrics_socket:sock didReadData:data withTag:tag];
}



// 实现新方法
- (void)metrics_disconnectWithReason:(TJPDisconnectReason)reason {
    // 记录会话断开
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeySessionDisconnects];
    
    // 调用原始方法
    [self metrics_disconnectWithReason:reason];
}

- (void)metrics_forceReconnect {
    // 记录会话重连
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeySessionReconnects];
    
    // 调用原始方法
    [self metrics_forceReconnect];
}

- (void)metrics_connection:(id)connection didDisconnectWithError:(NSError *)error reason:(TJPDisconnectReason)reason {
    // 记录错误
    if (error) {
        [[TJPMetricsCollector sharedInstance] recordError:error forKey:@"disconnect"];
    }
    
    // 调用原始方法
    [self metrics_connection:connection didDisconnectWithError:error reason:reason];
}

- (void)metrics_handleRetransmissionForSequence:(uint32_t)sequence {
    // 记录消息重传
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyMessageRetried];
    
    // 调用原始方法
    [self metrics_handleRetransmissionForSequence:sequence];
}

- (void)metrics_performVersionHandshake {
    // 记录控制消息
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyControlMessageSend];
    
    // 调用原始方法
    [self metrics_performVersionHandshake];
}


@end
