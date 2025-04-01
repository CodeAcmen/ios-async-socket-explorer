//
//  TJPCacheManager.h
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import <Foundation/Foundation.h>
#import "TJPCacheProtocol.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPCacheManager : NSObject <TJPCacheProtocol>

// 缓存策略的选择（可以是内存、磁盘或数据库缓存）
@property (nonatomic, strong) id<TJPCacheProtocol> cacheStrategy;

// 常用缓存时间
extern NSTimeInterval const TJPCacheExpireTimeShort;  // 短期缓存：5分钟
extern NSTimeInterval const TJPCacheExpireTimeMedium; // 中期缓存：1小时
extern NSTimeInterval const TJPCacheExpireTimeLong;   // 长期缓存：24小时


- (instancetype)initWithCacheStrategy:(id<TJPCacheProtocol>)cacheStrategy;

// 存储缓存数据
- (void)saveCacheWithData:(nonnull id)data forKey:(nonnull NSString *)key expireTime:(NSTimeInterval)expireTime;

// 读取缓存数据
- (id)loadCacheForKey:(NSString *)key;

// 删除缓存
- (void)removeCacheForKey:(NSString *)key;

// 清理所有缓存
- (void)clearAllCache;

@end

NS_ASSUME_NONNULL_END
