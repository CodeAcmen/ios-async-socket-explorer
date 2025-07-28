//
//  TJPNavigationDefines.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#ifndef TJPNavigationDefines_h
#define TJPNavigationDefines_h

typedef NS_ENUM(NSUInteger, TJPNavigationRouteType) {
    TJPNavigationRouteTypeUnknown = 0,
    TJPNavigationRouteTypeViewPush,                 // Push跳转
    TJPNavigationRouteTypeViewPresent,              // 弹出跳转
    TJPNavigationRouteTypeViewCustom,               // 自定义跳转
    TJPNavigationRouteTypeAction,                   // 跳转信号,但不执行动作
    TJPNavigationRouteTypeHybrid
};

typedef NS_ENUM(NSUInteger, TJPNavigationTransitionStyle) {
    TJPNavigationTransitionStyleDefault,
    TJPNavigationTransitionStyleFade,
    TJPNavigationTransitionStyleSlide
};

//typedef NS_OPTIONS(NSUInteger, TJPNavigationType) {
//    TJPNavigationTypePush,      // 普通Push跳转
//    TJPNavigationTypePresent,   // 弹出跳转
//    TJPNavigationTypeModal,     // Modal跳转
//    TJPNavigationTypeCustom     // 自定义跳转
//};


/**
 * 路由创建策略
 */
typedef NS_ENUM(NSInteger, TJPRouterCreationStrategy) {
    TJPRouterCreationStrategyHardcode,      // 硬编码创建
    TJPRouterCreationStrategyDI,            // 依赖注入创建
    TJPRouterCreationStrategyFactory        // 工厂模式创建
};



#endif /* TJPNavigationDefines_h */




