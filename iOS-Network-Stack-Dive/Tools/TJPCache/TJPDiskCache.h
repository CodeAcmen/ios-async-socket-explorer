//
//  TJPDiskCache.h
//  
//
//  Created by 唐佳鹏 on 2025/1/18.
//

#import <Foundation/Foundation.h>
#import "TJPCacheProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPDiskCache : NSObject <TJPCacheProtocol>

@property (nonatomic, strong) NSString *cacheDirectory; 

@end

NS_ASSUME_NONNULL_END
