//
//  TJPNetworkConfig.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//

#import "TJPNetworkConfig.h"

@implementation TJPNetworkConfig

- (instancetype)init {
    if (self = [super init]) {
        _maxRetry = 5;
        _heartbeat = 15.0;
        _baseDelay = 2.0;
    }
    return self;
}

@end
