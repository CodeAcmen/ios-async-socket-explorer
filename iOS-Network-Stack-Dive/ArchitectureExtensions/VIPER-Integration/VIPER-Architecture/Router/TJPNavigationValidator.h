//
//  TJPNavigationValidator.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  校验器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TJPNavigationModel;

@interface TJPNavigationValidator : NSObject


+ (BOOL)isValidModel:(TJPNavigationModel *)model;
+ (BOOL)validateViewTransitionParameters:(NSDictionary *)params;
+ (BOOL)validateServiceParameters:(NSDictionary *)params;
@end

NS_ASSUME_NONNULL_END
