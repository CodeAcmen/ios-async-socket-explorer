//
//  TJPMetricsCollector.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import "TJPMetricsCollector.h"
#import <os/lock.h>

NSString * const TJPMetricsKeyConnectionAttempts = @"connection_attempts";
NSString * const TJPMetricsKeyConnectionSuccess = @"connection_success";
NSString * const TJPMetricsKeyHeartbeatSend = @"heartbeat_send";
NSString * const TJPMetricsKeyHeartbeatLoss = @"heartbeat_loss";

NSString * const TJPMetricsKeyHeartbeatRTT = @"heartbeat_rtt";
NSString * const TJPMetricsKeyHeartbeatInterval = @"heartbeat_interval";
NSString * const TJPMetricsKeyHeartbeatTimeoutInterval = @"heartbeat_timeout_interval";


NSString * const TJPMetricsKeyRTT = @"rtt";

NSString * const TJPMetricsKeyBytesSend = @"bytes_send";
NSString * const TJPMetricsKeyBytesReceived = @"bytes_received";

NSString * const TJPMetricsKeyParsedPackets = @"parsed_packets_total";
NSString * const TJPMetricsKeyParsedPacketsTime = @"parse_packets_time";
NSString * const TJPMetricsKeyParsedBufferSize = @"parser_buffer_size";
NSString * const TJPMetricsKeyParseErrors = @"parse_errors_total";
NSString * const TJPMetricsKeyParsedErrorsTime = @"parse_error_time";


NSString * const TJPMetricsKeyPayloadBytes = @"payload_bytes_total";
NSString * const TJPMetricsKeyParserResets = @"parser_forced_resets";


@interface TJPMetricsCollector () {
    os_unfair_lock _lock;
    NSUInteger _bytesSend;
    NSUInteger _bytesReceived;
}


/*
    监控指标如下:
    connection_attempts:连接尝试次数
    connection_success:成功次数
 
    heartbeat_send:心跳发送
    heartbeat_loss:心跳丢失
    
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *counts;

//时间数据存储
@property (nonatomic, strong)  NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *timeSeries;


@end

@implementation TJPMetricsCollector

+ (instancetype)sharedInstance {
    static TJPMetricsCollector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPMetricsCollector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        
        // 初始化普通计数器
        _counts = [NSMutableDictionary dictionaryWithDictionary:@{
            TJPMetricsKeyConnectionAttempts: @0,
            TJPMetricsKeyConnectionSuccess: @0,
            TJPMetricsKeyHeartbeatSend: @0,
            TJPMetricsKeyHeartbeatLoss: @0,
            TJPMetricsKeyBytesSend: @0,
            TJPMetricsKeyBytesReceived: @0
        }];
        
        // 初始化时间序列
        _timeSeries = [NSMutableDictionary dictionary];
        
        // 初始化字节计数器
        _bytesSend = 0;
        _bytesReceived = 0;
    }
    return self;
}

#pragma mark - 计数器操作
- (void)incrementCounter:(NSString *)key {
    [self incrementCounter:key by:1];

}

- (void)incrementCounter:(NSString *)key by:(NSUInteger)value {
    [self performLocked:^{
        // 特殊处理字节计数器
        if ([key isEqualToString:TJPMetricsKeyBytesSend]) {
            self->_bytesSend += value;
        }
        else if ([key isEqualToString:TJPMetricsKeyBytesReceived]) {
            self->_bytesReceived += value;
        }else {
            NSNumber *currCount = self.counts[key] ?: @0;
            self.counts[key] = @(currCount.unsignedIntegerValue + value);
        }
    }];
}

- (NSUInteger)counterValue:(NSString *)key {
    __block NSUInteger value;
    [self performLocked:^{
        if ([key isEqualToString:TJPMetricsKeyBytesSend]) {
            value = self->_bytesSend;
        }
        else if ([key isEqualToString:TJPMetricsKeyBytesReceived]) {
            value = self->_bytesReceived;
        }
        else {
            value = [self.counts[key] unsignedIntegerValue];
        }
    }];
    return value;
}


- (void)addValue:(NSUInteger)value forKey:(NSString *)key {
    [self performLocked:^{
        // 如果字典中已存在该key，累加该值
        NSNumber *currentValue = self.counts[key];
        if (currentValue) {
            self.counts[key] = @(currentValue.unsignedIntegerValue + value);
        } else {
            // 如果字典中不存在该key，初始化该key的值
            self.counts[key] = @(value);
        }
    }];
}


#pragma mark - 时间序列记录
- (void)addTimeSample:(NSTimeInterval)duration forKey:(NSString *)key {
    [self performLocked:^{
        NSMutableArray *samples = self.timeSeries[key];
        if (!samples) {
            samples = [NSMutableArray array];
            self.timeSeries[key] = samples;
        }
        
        [samples addObject:@(duration)];
        
        //保留最近1000个样本数据
        if (samples.count > 1000) {
            [samples removeObjectsInRange:NSMakeRange(0, samples.count - 1000)];
        }
    }];
}

- (NSTimeInterval)averageDuration:(NSString *)key {
    __block NSTimeInterval total = 0;
    __block NSUInteger count = 0;
    [self performLocked:^{
        NSArray *samples = self.timeSeries[key];
        count = samples.count;
        for (NSNumber *num in samples) {
            total += num.doubleValue;
        }
    }];
    return count > 0 ? total / count : 0;
}

#pragma mark - 指标相关
- (float)connectSuccessRate {
    NSUInteger attempts = [self counterValue:TJPMetricsKeyConnectionAttempts];
    NSUInteger success = [self counterValue:TJPMetricsKeyConnectionSuccess];
    float ratio = (attempts > 0) ? (float)success / (float)attempts : 0;  // 防止除以0
    return success > 0 ? ratio : 0;
}


- (NSTimeInterval)averageRTT {
    return [self averageDuration:TJPMetricsKeyRTT];
}

- (float)packetLossRate {
    NSUInteger send = [self counterValue:TJPMetricsKeyHeartbeatSend];
    NSUInteger loss = [self counterValue:TJPMetricsKeyHeartbeatLoss];
    float ratio = (send > 0) ? (float)loss / (float)send : 0;  // 防止除以0
    return loss > 0 ? ratio : 0;
}


- (NSTimeInterval)averageStateDuration:(TJPConnectState)state {
    return [self averageDuration:[NSString stringWithFormat:@"state_%@", state]];
}

- (NSTimeInterval)averageEventDuration:(TJPConnectEvent)event {
    return [self averageDuration:[NSString stringWithFormat:@"event_%@", event]];
}



#pragma mark - 线程安全操作
- (void)performLocked:(void (^)(void))block {
    os_unfair_lock_lock(&_lock);
    block();
    os_unfair_lock_unlock(&_lock);
}


@end
