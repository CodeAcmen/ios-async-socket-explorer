//
//  TJPNavigationValidator.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPNavigationValidator.h"
#import "TJPNavigationModel.h"

@implementation TJPNavigationValidator


+ (BOOL)isValidModel:(TJPNavigationModel *)model {
    if (!model) return NO;
    if (![model isKindOfClass:[TJPNavigationModel class]]) return NO;
    if (model.routeId.length == 0) return NO;
    return YES;
}

+ (BOOL)validateViewTransitionParameters:(NSDictionary *)params {
    // 验证必须参数
    if (!params[@"viewControllerClass"]) return NO;
    if (![params[@"viewControllerClass"] isKindOfClass:[NSString class]]) return NO;
    return YES;
}

+ (BOOL)validateServiceParameters:(NSDictionary *)params {
    
    return YES;
}

@end
