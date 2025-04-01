//
//  TJPMemoryCache.m
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import "TJPMemoryCache.h"
#import "TJPNetworkDefine.h"

@implementation TJPMemoryCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cacheExpiryTimes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)saveCacheWithData:(id)data forKey:(NSString *)key {
    [self.cache setObject:data forKey:key];
}

// 存储缓存数据，添加过期时间
- (void)saveCacheWithData:(id)data forKey:(NSString *)key expireTime:(NSTimeInterval)expireTime {
    if (data && key) {
        [self.cache setObject:data forKey:key];
        TJPLOG_INFO(@"JZMemoryCache save cache with data for key: %@", key);
        // 设置过期时间
        NSTimeInterval expiryTimestamp = [[NSDate date] timeIntervalSince1970] + expireTime;
        self.cacheExpiryTimes[key] = @(expiryTimestamp);
    }
}

// 读取缓存数据，并检查是否过期
- (id)loadCacheForKey:(NSString *)key {
    NSNumber *expiryTimestamp = self.cacheExpiryTimes[key];
    
    if (expiryTimestamp) {
        NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
        if (currentTimestamp > [expiryTimestamp doubleValue]) {
            // 缓存过期，删除缓存并返回nil
            [self.cache removeObjectForKey:key];
            [self.cacheExpiryTimes removeObjectForKey:key];
            return nil;
        }
    }
    TJPLOG_INFO(@"JZMemoryCache load cache for key: %@", key);
    return [self.cache objectForKey:key];
}

// 删除缓存数据
- (void)removeCacheForKey:(NSString *)key {
    [self.cache removeObjectForKey:key];
    [self.cacheExpiryTimes removeObjectForKey:key];
    TJPLOG_INFO(@"JZMemoryCache remove cache for key: %@", key);
}

// 清除所有缓存
- (void)clearAllCache {
    [self.cache removeAllObjects];
    [self.cacheExpiryTimes removeAllObjects];
    TJPLOG_INFO(@"JZMemoryCache clear all cache");

}

@end
