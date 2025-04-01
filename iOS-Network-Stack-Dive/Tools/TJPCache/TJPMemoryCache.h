//
//  TJPMemoryCache.h
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import <Foundation/Foundation.h>
#import "TJPCacheProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPMemoryCache : NSObject <TJPCacheProtocol>
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSMutableDictionary *cacheExpiryTimes;

@end

NS_ASSUME_NONNULL_END
