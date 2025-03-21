//
//  TJPNETErrorHandler.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TJPNetworkManagerV1;
@interface TJPNETErrorHandler : NSObject

+ (void)handleError:(NSError *)error inManager:(TJPNetworkManagerV1 *)manager;

@end

NS_ASSUME_NONNULL_END
