//
//  TJPMessageParser+TJPMetrics.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/10.
//

#import "TJPMessageParser+TJPMetrics.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "TJPMetricsCollector.h"
#import "TJPParsedPacket.h"


@implementation TJPMessageParser (TJPMetrics)

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleFeedData];
        [self swizzleNextPacket];
        [self swizzleReset];
    });
}

+ (void)swizzleFeedData {
    Class class = [self class];
    
    SEL originSEL = @selector(feedData:);
    SEL swizzledSEL = @selector(metrics_feedData:);
    
    Method originMethod = class_getInstanceMethod(class, originSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    method_exchangeImplementations(originMethod, swizzledMethod);
    
}

+ (void)swizzleNextPacket {
    Class class = [self class];
    
    SEL originSEL = @selector(nextPacket);
    SEL swizzledSEL = @selector(metrics_nextPacket);
    
    Method originMethod = class_getInstanceMethod(class, originSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    method_exchangeImplementations(originMethod, swizzledMethod);
}

+ (void)swizzleReset {
    Class class = [self class];
    
    SEL originSEL = @selector(reset);
    SEL swizzledSEL = @selector(metrics_reset);
    
    Method originMethod = class_getInstanceMethod(class, originSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    method_exchangeImplementations(originMethod, swizzledMethod);
    
}


#pragma mark - Swizzled Methods
- (void)metrics_feedData:(NSData *)data {
    // 记录输入流量
    [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyBytesReceived by:data.length];
    [self metrics_feedData:data];
}

- (TJPParsedPacket *)metrics_nextPacket {
    TJPMetricsCollector *metrics = [TJPMetricsCollector sharedInstance];
    
    // 记录缓冲区状态
    [metrics addValue:self.buffer.length forKey:TJPMetricsKeyParsedBufferSize];
    
    NSTimeInterval start = CACurrentMediaTime();
    TJPParsedPacket *packet = [self metrics_nextPacket];
    NSTimeInterval duration = CACurrentMediaTime() - start;
    
    if (packet) {
        // 成功解析埋点
        NSString *typeKey = [NSString stringWithFormat:@"packet_type_%d", packet.header.msgType];
        [metrics incrementCounter:typeKey];
        
        [metrics addTimeSample:duration forKey:TJPMetricsKeyParsedPacketsTime];
        [metrics incrementCounter:TJPMetricsKeyParsedPackets];
        
        // 有效载荷大小统计
        if (packet.payload) {
            [metrics incrementCounter:TJPMetricsKeyPayloadBytes by:packet.payload.length];
        }
    } else {
        // 解析失败埋点
        [metrics incrementCounter:TJPMetricsKeyParseErrors];
        [metrics addTimeSample:duration forKey:TJPMetricsKeyParsedErrorsTime];
    }
    
    return packet;
}

- (void)metrics_reset {
    // 记录异常重置事件
    if (self.buffer.length > 0) {
        [[TJPMetricsCollector sharedInstance] incrementCounter:TJPMetricsKeyParserResets];
    }
    [self metrics_reset];
}





@end




