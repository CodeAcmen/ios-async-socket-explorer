//
//  TJPDiskCache.m
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import "TJPDiskCache.h"

@implementation TJPDiskCache

- (instancetype)init {
    self = [super init];
    if (self) {
        // 设定缓存目录，默认在应用沙盒的Documents目录
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _cacheDirectory = [paths.firstObject stringByAppendingPathComponent:@"cache"];
        
        // 创建缓存目录
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.cacheDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return self;
}

// 存储缓存数据，添加过期时间
- (void)saveCacheWithData:(id)data forKey:(NSString *)key expireTime:(NSTimeInterval)expireTime {
    if (data && key) {
        NSString *filePath = [self cacheFilePathForKey:key];
        [data writeToFile:filePath atomically:YES];
        
        // 存储过期时间
        NSTimeInterval expiryTimestamp = [[NSDate date] timeIntervalSince1970] + expireTime;
        NSNumber *expiryNumber = @(expiryTimestamp);
        NSData *expiryData = [NSKeyedArchiver archivedDataWithRootObject:expiryNumber];
        
        NSString *expiryFilePath = [self cacheExpiryFilePathForKey:key];
        [expiryData writeToFile:expiryFilePath atomically:YES];
    }
}

// 读取缓存数据，并检查是否过期
- (id)loadCacheForKey:(NSString *)key {
    NSString *filePath = [self cacheFilePathForKey:key];
    NSString *expiryFilePath = [self cacheExpiryFilePathForKey:key];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *expiryData = [NSData dataWithContentsOfFile:expiryFilePath];
        NSNumber *expiryTimestamp = [NSKeyedUnarchiver unarchiveObjectWithData:expiryData];
        
        if (expiryTimestamp) {
            NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
            if (currentTimestamp > [expiryTimestamp doubleValue]) {
                // 缓存过期，删除缓存并返回nil
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:expiryFilePath error:nil];
                return nil;
            }
        }
        
        return [NSData dataWithContentsOfFile:filePath]; // 返回数据
    }
    
    return nil;
}


// 删除缓存数据
- (void)removeCacheForKey:(NSString *)key {
    NSString *filePath = [self cacheFilePathForKey:key];
    NSString *expiryFilePath = [self cacheExpiryFilePathForKey:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:expiryFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:expiryFilePath error:nil];
    }
}

// 清除所有缓存
- (void)clearAllCache {
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDirectory error:&error];
    if (!error) {
        for (NSString *file in files) {
            NSString *filePath = [self.cacheDirectory stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
}

// 获取缓存文件路径
- (NSString *)cacheFilePathForKey:(NSString *)key {
    return [self.cacheDirectory stringByAppendingPathComponent:key];
}

// 获取缓存过期时间文件路径
- (NSString *)cacheExpiryFilePathForKey:(NSString *)key {
    return [[self.cacheDirectory stringByAppendingPathComponent:key] stringByAppendingPathExtension:@"expiry"];
}


@end
