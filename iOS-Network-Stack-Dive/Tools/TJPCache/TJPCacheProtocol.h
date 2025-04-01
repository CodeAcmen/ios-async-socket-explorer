//
//  TJPCacheProtocol.h
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPCacheProtocol <NSObject>

// 存储数据
- (void)saveCacheWithData:(id)data forKey:(NSString *)key expireTime:(NSTimeInterval)expireTime;

// 读取数据
- (id)loadCacheForKey:(NSString *)key;

// 删除缓存
- (void)removeCacheForKey:(NSString *)key;

// 清除所有缓存
- (void)clearAllCache;

@end

NS_ASSUME_NONNULL_END
