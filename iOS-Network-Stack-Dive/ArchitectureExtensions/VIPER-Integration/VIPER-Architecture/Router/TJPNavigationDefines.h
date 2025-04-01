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
    TJPNavigationRouteTypeViewPush,
    TJPNavigationRouteTypeViewPresent,
    TJPNavigationRouteTypeServiceCall,
    TJPNavigationRouteTypeHybrid
};

typedef NS_ENUM(NSUInteger, TJPNavigationTransitionStyle) {
    TJPNavigationTransitionStyleDefault,
    TJPNavigationTransitionStyleFade,
    TJPNavigationTransitionStyleSlide
};

typedef NS_OPTIONS(NSUInteger, TJPNavigationType) {
    TJPNavigationTypePush,      // 普通Push跳转
    TJPNavigationTypePresent,   // 弹出跳转
    TJPNavigationTypeModal,     // Modal跳转
    TJPNavigationTypeCustom     // 自定义跳转
};





#endif /* TJPNavigationDefines_h */




