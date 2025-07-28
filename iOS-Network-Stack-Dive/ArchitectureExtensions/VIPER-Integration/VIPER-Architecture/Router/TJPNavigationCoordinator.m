//
//  TJPNavigationCoordinator.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPNavigationCoordinator.h"
#import "TJPViperBaseRouterHandlerProtocol.h"
#import "TJPNavigationModel.h"
#import "TJPNetworkDefine.h"


@interface TJPNavigationCoordinator ()

@end

@implementation TJPNavigationCoordinator


+ (instancetype)sharedInstance {
    static TJPNavigationCoordinator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPNavigationCoordinator alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _handlers = [NSMapTable strongToWeakObjectsMapTable];
        _syncQueue = dispatch_queue_create("com.tjp.navigationCoordinator.syncQyeye", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (void)registerHandler:(id<TJPViperBaseRouterHandlerProtocol>)handler forRouteType:(TJPNavigationRouteType)routeType {
    if (!handler || routeType == TJPNavigationRouteTypeUnknown) {
        TJPLOG_ERROR(@"当前路由类型未知,请检查   routeType: %lu", (unsigned long)routeType);
        return;
    }
    
    dispatch_async(self.syncQueue, ^{
        [self.handlers setObject:handler forKey:@(routeType)];
        TJPLOG_INFO(@"添加类型处理器: %@ 类型:%lu", handler, (unsigned long)routeType);
    });
}

- (void)unregisterHandlerForRouteType:(TJPNavigationRouteType)routeType {
    dispatch_async(self.syncQueue, ^{
        [self.handlers removeObjectForKey:@(routeType)];
    });
}

- (id<TJPViperBaseRouterHandlerProtocol>)handlerForRouteType:(TJPNavigationRouteType)routeType {
    __block id<TJPViperBaseRouterHandlerProtocol> handler;
    dispatch_sync(self.syncQueue, ^{
        handler = [self.handlers objectForKey:@(routeType)];
    });
    return handler;
}

- (BOOL)dispatchRequestWithModel:(TJPNavigationModel *)model inContext:(UIViewController *)context{
    if (!model || model.routeId.length == 0) {
        NSLog(@"[NavigationCoordinator] 无效的 NavigationModel");
        return NO;
    }
    
    __block id<TJPViperBaseRouterHandlerProtocol> handler = nil;
    dispatch_sync(self.syncQueue, ^{
        handler = [self.handlers objectForKey:@(model.routeType)];
    });
    
    if (!handler) {
        NSLog(@"[NavigationCoordinator] 未找到对应的 Handler：routeType = %ld", (long)model.routeType);
//        if ([self.delegate respondsToSelector:@selector(coordinator:didFailWithUnregisteredRouteType:)]) {
//            [self.delegate coordinator:self didFailWithUnregisteredRouteType:model.routeType];
//        }
        return NO;
    }
    
    //策略模式分发
    return [handler handleRequestWithModel:model context:context];
}


@end

