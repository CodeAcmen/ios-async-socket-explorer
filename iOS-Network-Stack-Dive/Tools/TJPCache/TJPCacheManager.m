//
//  TJPCacheManager.m
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import "TJPCacheManager.h"

@interface TJPCacheManager ()

@end

@implementation TJPCacheManager

// 常用缓存时间定义
NSTimeInterval const TJPCacheExpireTimeShort = 5 * 60;   // 5分钟
NSTimeInterval const TJPCacheExpireTimeMedium = 60 * 60;  // 1小时
NSTimeInterval const TJPCacheExpireTimeLong = 24 * 60 * 60; // 24小时

- (instancetype)initWithCacheStrategy:(id<TJPCacheProtocol>)cacheStrategy {
    self = [super init];
    if (self) {
        _cacheStrategy = cacheStrategy;
    }
    return self;
}

- (void)saveCacheWithData:(nonnull id)data forKey:(nonnull NSString *)key expireTime:(NSTimeInterval)expireTime {
    [self.cacheStrategy saveCacheWithData:data forKey:key expireTime:expireTime];
}

- (id)loadCacheForKey:(NSString *)key {
    return [self.cacheStrategy loadCacheForKey:key];
}

- (void)removeCacheForKey:(NSString *)key {
    [self.cacheStrategy removeCacheForKey:key];
}

- (void)clearAllCache {
    [self.cacheStrategy clearAllCache];
}

@end
