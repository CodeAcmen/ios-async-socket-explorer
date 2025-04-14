//
//  TJPNetworkConfig.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//

#import "TJPNetworkConfig.h"

@implementation TJPNetworkConfig

+ (instancetype)configWithMaxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat {
    return [[TJPNetworkConfig alloc] initWithMaxRetry:maxRetry heartbeat:heartbeat];
}

- (instancetype)initWithMaxRetry:(NSUInteger)maxRetry heartbeat:(CGFloat)heartbeat {
    if (self = [super init]) {
        _maxRetry = maxRetry;
        _heartbeat = heartbeat;
        _baseDelay = 2.0;
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        _maxRetry = 5;
        _heartbeat = 15.0;
        _baseDelay = 2.0;
    }
    return self;
}

@end
