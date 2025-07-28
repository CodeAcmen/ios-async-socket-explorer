//
//  TJPNavigationModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <UIKit/UIKit.h>
#import "TJPNavigationDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPNavigationModel : NSObject

/// 路由id
@property (nonatomic, copy) NSString *routeId;
/// 跳转参数
@property (nonatomic, strong) NSDictionary *parameters;
/// 时间戳
@property (nonatomic, assign) NSTimeInterval timestamp;
/// 跳转类型
@property (nonatomic, assign) TJPNavigationRouteType routeType;
/// 是否显示动画
@property (nonatomic, assign) BOOL animated;

@property (nonatomic, strong) UIViewController *targetVC;



+ (instancetype)modelWithRouteId:(NSString *)routeId parameters:(NSDictionary *)params routeType:(TJPNavigationRouteType)routeType;

@end

NS_ASSUME_NONNULL_END
