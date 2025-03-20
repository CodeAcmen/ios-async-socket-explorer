//
//  TJPNETErrorHandler.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TJPNetworkManager;
@interface TJPNETErrorHandler : NSObject

+ (void)handleError:(NSError *)error inManager:(TJPNetworkManager *)manager;

@end

NS_ASSUME_NONNULL_END
