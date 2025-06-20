//
//  TJPLogManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/19.
//

#import "TJPLogManager.h"

@interface TJPLogManager () {
    NSMutableDictionary<NSString *, NSNumber *> *_lastLogTimes;
    dispatch_queue_t _logQueue;
    dispatch_semaphore_t _lock;
}

@end

@implementation TJPLogManager

+ (instancetype)sharedManager {
    static TJPLogManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPLogManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // 默认关闭详细日志
        _debugLoggingEnabled = NO;
        // 限流 3秒
        _logThrottleInterval = 3.0;
        _minLogLevel = TJPLogLevelWarn;
        _lastLogTimes = [NSMutableDictionary dictionary];
        
        _lock = dispatch_semaphore_create(1);
        // 低优先级队列节省CPU
        _logQueue = dispatch_queue_create("com.TJPLogManager.logQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_logQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    }
    return self;
}

+ (TJPLogLevel)levelFromString:(NSString *)levelString {
    levelString = [levelString uppercaseString];
    if ([levelString isEqualToString:@"DEBUG"]) return TJPLogLevelDebug;
    if ([levelString isEqualToString:@"INFO"])  return TJPLogLevelInfo;
    if ([levelString isEqualToString:@"WARN"])  return TJPLogLevelWarn;
    if ([levelString isEqualToString:@"MOCK"])  return TJPLogLevelMock;
    if ([levelString isEqualToString:@"ERROR"]) return TJPLogLevelError;
    return TJPLogLevelDebug;
}

+ (NSString *)stringFromLevel:(TJPLogLevel)level {
    switch (level) {
        case TJPLogLevelDebug: return @"DEBUG";
        case TJPLogLevelInfo:  return @"INFO";
        case TJPLogLevelWarn:  return @"WARN";
        case TJPLogLevelMock:  return @"MOCK";
        case TJPLogLevelError: return @"ERROR";
        default:               return @"DEBUG";
    }
}

- (BOOL)shouldLogWithLevel:(TJPLogLevel)level {
    if (level < _minLogLevel) return NO;
    if (!_debugLoggingEnabled && level < TJPLogLevelWarn) return NO;
    return YES;
}

- (void)throttledLog:(NSString *)message level:(NSUInteger)level tag:(NSString *)tag {
    if (!tag || tag.length == 0) tag = @"Default";

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    __block BOOL shouldOutput = NO;

    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSNumber *lastTime = _lastLogTimes[tag];
    if (!lastTime || (now - lastTime.doubleValue) >= _logThrottleInterval) {
        _lastLogTimes[tag] = @(now);
        shouldOutput = YES;
    }
    dispatch_semaphore_signal(_lock);

    if (!shouldOutput) return;
    
    // 异步低优先级输出，不阻塞主要逻辑
    dispatch_async(_logQueue, ^{
        NSString *levelString = [TJPLogManager stringFromLevel:level];
        NSLog(@"[TJPIM][%@][%@] %@", levelString, tag, message);
    });
}

@end
