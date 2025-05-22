//
//  TJPNetworkConfig.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//

#import "TJPNetworkConfig.h"
#import "TJPNetworkDefine.h"

@implementation TJPNetworkConfig

- (void)dealloc {
    TJPLogDealloc();
}

+ (instancetype)configWithHost:(NSString *)host port:(uint16_t)port maxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat {
    return [[TJPNetworkConfig alloc] initWithHost:host port:port maxRetry:maxRetry heartbeat:heartbeat];
}

+ (instancetype)defaultConfig {
    return [[TJPNetworkConfig alloc] init];
}

- (instancetype)init {
    return [self initWithHost:@"127.0.0.1" port:8080 maxRetry:5 heartbeat:15.0];
}

- (instancetype)initWithHost:(NSString *)host port:(uint16_t)port maxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat {
    if (self = [super init]) {
        _host = host;
        _port = port;
        _maxRetry = maxRetry;
        _heartbeat = heartbeat;
        _baseDelay = 2.0;
        _shouldReconnectAfterBackground = YES;
        _shouldReconnectAfterServerClose = NO;
        _useTLS = NO;
        _connectTimeout = 15.0;
        
        
        // 默认指标设置
#ifdef DEBUG
        _metricsLevel = TJPMetricsLevelStandard;
        _metricsConsoleEnabled = YES;
#else
        _metricsLevel = TJPMetricsLevelBasic;
        _metricsConsoleEnabled = NO;
#endif
        _metricsReportInterval = 15.0;
    }
    return self;
}



@end
