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
#import "TJPNavigationValidator.h"


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

- (BOOL)dispatchRequestWithModel:(TJPNavigationModel *)model routeType:(TJPNavigationRouteType)routeType inContext:(UIViewController *)context {
    if (![TJPNavigationValidator isValidModel:model]) {
        TJPLOG_ERROR(@"当前模型检查出错  model:%@", model);
        return NO;
    }
    
    __block id<TJPViperBaseRouterHandlerProtocol> handler = nil;
    dispatch_sync(self.syncQueue, ^{
        handler = [self.handlers objectForKey:@(routeType)];
    });
    
    if (!handler) {
        TJPLOG_WARN(@"No handler for route type: %ld", (long)routeType);
        return NO;
    }
    
    //策略模式分发
    return [handler handleRequestWithModel:model context:context];
}


@end

