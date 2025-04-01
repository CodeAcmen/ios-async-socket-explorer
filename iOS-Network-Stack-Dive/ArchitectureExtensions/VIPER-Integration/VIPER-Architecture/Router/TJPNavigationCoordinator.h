//
//  TJPNavigationCoordinator.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  路由中枢类

#import <UIKit/UIKit.h>
#import "TJPNavigationDefines.h"

NS_ASSUME_NONNULL_BEGIN


@protocol TJPViperBaseRouterHandlerProtocol;

@class TJPNavigationModel;

@interface TJPNavigationCoordinator : NSObject

@property (nonatomic, strong) dispatch_queue_t syncQueue;
//Coordinator弱引用持有handler
@property (nonatomic, strong) NSMapTable<NSNumber *, id> *handlers;




+ (instancetype)sharedInstance;

/// 注册处理器 建议应用启动时注册
- (void)registerHandler:(id<TJPViperBaseRouterHandlerProtocol>)handler forRouteType:(TJPNavigationRouteType)routeType;

/// 取消注册
- (void)unregisterHandlerForRouteType:(TJPNavigationRouteType)routeType;

- (id<TJPViperBaseRouterHandlerProtocol>)handlerForRouteType:(TJPNavigationRouteType)routeType;


- (BOOL)dispatchRequestWithModel:(TJPNavigationModel *)model routeType:(TJPNavigationRouteType)routeType inContext:(UIViewController *)context;

@end

NS_ASSUME_NONNULL_END
