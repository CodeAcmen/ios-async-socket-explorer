//
//  TJPMetricsCollector.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import "TJPMetricsCollector.h"
#import "TJPMetricsKeys.h"
#import <os/lock.h>

//NSString * const TJPMetricsKeyConnectionAttempts = @"connection_attempts";
//NSString * const TJPMetricsKeyConnectionSuccess = @"connection_success";

//NSString * const TJPMetricsKeyHeartbeatSend = @"heartbeat_send";
//NSString * const TJPMetricsKeyHeartbeatLoss = @"heartbeat_loss";
//NSString * const TJPMetricsKeyHeartbeatRTT = @"heartbeat_rtt";
//NSString * const TJPMetricsKeyHeartbeatInterval = @"heartbeat_interval";
//NSString * const TJPMetricsKeyHeartbeatTimeoutInterval = @"heartbeat_timeout_interval";


//NSString * const TJPMetricsKeyRTT = @"rtt";

NSString * const TJPMetricsKeyBytesSend = @"bytes_send";
NSString * const TJPMetricsKeyBytesReceived = @"bytes_received";

NSString * const TJPMetricsKeyParsedPackets = @"parsed_packets_total";
NSString * const TJPMetricsKeyParsedPacketsTime = @"parse_packets_time";
NSString * const TJPMetricsKeyParsedBufferSize = @"parser_buffer_size";
NSString * const TJPMetricsKeyParseErrors = @"parse_errors_total";
NSString * const TJPMetricsKeyParsedErrorsTime = @"parse_error_time";


NSString * const TJPMetricsKeyPayloadBytes = @"payload_bytes_total";
NSString * const TJPMetricsKeyParserResets = @"parser_forced_resets";


NSString * const TJPMetricsKeyMessageSend = @"message_send_total";
NSString * const TJPMetricsKeyMessageAcked = @"message_acked_total";
NSString * const TJPMetricsKeyMessageTimeout = @"message_timeout_total";

// 消息类型统计指标
NSString * const TJPMetricsKeyControlMessageSend = @"control_message_send";
NSString * const TJPMetricsKeyNormalMessageSend = @"normal_message_send";
NSString * const TJPMetricsKeyMessageRetried = @"message_retried_total";


NSString * const TJPMetricsKeyErrorCount = @"error_count";
NSString * const TJPMetricsKeySessionReconnects = @"session_reconnects";
NSString * const TJPMetricsKeySessionDisconnects = @"session_disconnects";


@interface TJPMetricsCollector () {
    os_unfair_lock _lock;
    NSUInteger _bytesSend;
    NSUInteger _bytesReceived;
}


//指标数量监控
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *counts;

//时间数据存储
@property (nonatomic, strong)  NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *timeSeries;

//错误存储
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *errors;

//事件
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *events;


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
        
        // 初始化计数器
        _counts = [NSMutableDictionary dictionaryWithDictionary:@{
            // 连接相关
            TJPMetricsKeyConnectionAttempts: @0,
            TJPMetricsKeyConnectionSuccess: @0,
            
            // 心跳相关
            TJPMetricsKeyHeartbeatSend: @0,
            TJPMetricsKeyHeartbeatLoss: @0,
            
            // 流量统计
            TJPMetricsKeyBytesSend: @0,
            TJPMetricsKeyBytesReceived: @0,
            
            // 数据包解析
            TJPMetricsKeyParsedPackets: @0,
            TJPMetricsKeyParsedPacketsTime: @0,
            TJPMetricsKeyParsedBufferSize: @0,
            TJPMetricsKeyParseErrors: @0,
            TJPMetricsKeyParsedErrorsTime: @0,
            TJPMetricsKeyPayloadBytes: @0,
            TJPMetricsKeyParserResets: @0,
            
            // 消息统计
            TJPMetricsKeyMessageSend: @0,
            TJPMetricsKeyMessageAcked: @0,
            TJPMetricsKeyMessageTimeout: @0,
            
            // 错误和会话状态
            TJPMetricsKeyErrorCount: @0,
            TJPMetricsKeySessionReconnects: @0,
            TJPMetricsKeySessionDisconnects: @0
        }];
        
        // 初始化时间序列
        _timeSeries = [NSMutableDictionary dictionary];
        
        // 初始化字节计数器
        _bytesSend = 0;
        _bytesReceived = 0;
        
        _events = [NSMutableDictionary dictionary];
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
            // 如果键不存在，添加一个默认值0
            if (!self.counts[key]) {
                self.counts[key] = @0;
            }
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


#pragma mark - 错误记录
- (void)recordError:(NSError *)error forKey:(NSString *)key {
    [self performLocked:^{
        if (!self.errors) {
            self.errors = [NSMutableArray array];
        }
        
        [self.errors addObject:@{
            @"time": [NSDate date],
            @"key": key ?: @"unknown",
            @"code": @(error.code),
            @"message": error.localizedDescription ?: @"No description"
        }];
        
        // 只保留最近的30条错误
        if (self.errors.count > 30) {
            [self.errors removeObjectsInRange:NSMakeRange(0, self.errors.count - 30)];
        }
        
        // 增加错误计数
        [self incrementCounter:TJPMetricsKeyErrorCount];
    }];
}

- (NSArray<NSDictionary *> *)recentErrors {
    __block NSArray *result;
    [self performLocked:^{
        result = [self.errors copy];
    }];
    return result;
}

- (void)recordEvent:(NSString *)eventName withParameters:(NSDictionary *)params {
    [self performLocked:^{
        // 确保事件数组存在
        NSMutableArray *eventArray = self.events[eventName];
        if (!eventArray) {
            eventArray = [NSMutableArray array];
            self.events[eventName] = eventArray;
        }
        
        // 创建事件记录
        NSMutableDictionary *eventRecord = [NSMutableDictionary dictionaryWithDictionary:params ?: @{}];
        eventRecord[@"timestamp"] = [NSDate date];
        
        // 添加事件
        [eventArray addObject:eventRecord];
        
        // 限制每种事件最多存储100条记录
        if (eventArray.count > 100) {
            [eventArray removeObjectsInRange:NSMakeRange(0, eventArray.count - 100)];
        }
    }];
}

- (NSArray<NSDictionary *> *)recentEventsForName:(NSString *)eventName limit:(NSUInteger)limit {
    __block NSArray *result;
    [self performLocked:^{
        NSArray *events = self.events[eventName] ?: @[];
        NSUInteger count = MIN(limit, events.count);
        if (count == 0) {
            result = @[];
            return;
        }
        result = [events subarrayWithRange:NSMakeRange(events.count - count, count)];
    }];
    return result;
}



#pragma mark - 线程安全操作
- (void)performLocked:(void (^)(void))block {
    os_unfair_lock_lock(&_lock);
    block();
    os_unfair_lock_unlock(&_lock);
}




@end
