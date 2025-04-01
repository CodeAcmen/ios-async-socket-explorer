//
//  TJPNavigationModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPNavigationModel : NSObject

/*
 // 路由ID命名规则示例
 static NSString * const TJPRouteIDMessageDetail = @"message/detail";
 static NSString * const TJPRouteIDUserProfile = @"user/profile";
 static NSString * const TJPRouteIDSettings = @"app/settings";
 
 */

/// 路由id
@property (nonatomic, copy) NSString *routeId;
/// 跳转参数
@property (nonatomic, strong) NSDictionary *parameters;
/// 时间戳
@property (nonatomic, assign) NSTimeInterval timestamp;


+ (instancetype)modelWithRouteId:(NSString *)routeId parameters:(NSDictionary *)params;

@end

NS_ASSUME_NONNULL_END
