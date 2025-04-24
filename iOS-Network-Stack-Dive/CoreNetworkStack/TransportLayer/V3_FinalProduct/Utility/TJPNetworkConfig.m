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

- (instancetype)initWithHost:(NSString *)host port:(uint16_t)port maxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat {
    if (self = [super init]) {
        _host = host;
        _port = port;
        _maxRetry = maxRetry;
        _heartbeat = heartbeat;
        _baseDelay = 2.0;
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        _host = @"127.0.0.1";
        _port = 8080;
        _maxRetry = 5;
        _heartbeat = 15.0;
        _baseDelay = 2.0;
        _shouldReconnectAfterBackground = YES;
        _shouldReconnectAfterServerClose = NO;
    }
    return self;
}

@end
