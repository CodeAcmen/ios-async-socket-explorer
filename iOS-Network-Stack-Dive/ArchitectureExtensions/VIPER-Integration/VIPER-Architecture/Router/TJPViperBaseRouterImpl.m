//
//  TJPViperBaseRouterImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseRouterImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPNavigationModel.h"
#import "TJPNavigationDefines.h"
#import "TJPViperDefaultErrorHandler.h"

#import "TJPNavigationCoordinator.h"


@interface TJPViperBaseRouterImpl ()

@end


@implementation TJPViperBaseRouterImpl


#pragma mark - LifeCycle
- (instancetype)initWithModuleProvider:(id)moduleProvider {
    if (self = [super init]) {
        _moduleProvider = moduleProvider;
        _enableNavigationAnimation = YES;
        _enableNavigationLog = YES;
        _creationStrategy = TJPRouterCreationStrategyDI; // 默认DI方式
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
}

#pragma mark - TJPViperBaseRouterHandlerProtocol
- (BOOL)navigateToRouteWithNavigationModel:(TJPNavigationModel *)model fromContext:(UIViewController *)context animated:(BOOL)animated {
    // 生命周期：准备导航
    [self willNavigateToRoute:model.routeId parameters:model.parameters];
    
    if (self.enableNavigationLog) {
        NSLog(@"[%@] 开始导航: %@ -> %@", NSStringFromClass([self class]), NSStringFromClass([context class]), model.routeId);
    }
    
    // 参数验证
    if (![self validateRoute:model.routeId parameters:model.parameters]) {
        NSLog(@"[%@] 路由验证失败: %@", NSStringFromClass([self class]), model.routeId);
        [self didNavigateToRoute:model.routeId success:NO];
        return NO;
    }
    
    // 参数预处理
    NSDictionary *processedParams = [self processParametersForRoute:model.routeId parameters:model.parameters];
    model.parameters = processedParams;
    model.animated = animated;
    
    // ===== 定义模板方法 子类重写并创建ViewController  支持硬编码及DI注入======
    UIViewController *targetVC = [self createViewControllerForRoute:model.routeId parameters:processedParams];
    if (!targetVC) {
        NSLog(@"[%@] 创建ViewController失败: %@", NSStringFromClass([self class]), model.routeId);
        [self didNavigateToRoute:model.routeId success:NO];
        return NO;
    }
    
    // 配置ViewController
    [self configureViewController:targetVC forRoute:model.routeId parameters:processedParams];
    model.targetVC = targetVC;

        
    // 使用协调器模式分发路由请求 确保Handler系统正常工作
    BOOL success = [self dispatchNavigationWithModel:model fromContext:context];

    // 生命周期：导航完成
    [self didNavigateToRoute:model.routeId success:success];
    
    if (self.enableNavigationLog) {
        NSLog(@"[%@] 导航结果: %@ %@", NSStringFromClass([self class]), model.routeId, success ? @"成功" : @"失败");
    }
    return success;
}

- (BOOL)dispatchNavigationWithModel:(TJPNavigationModel *)model fromContext:(UIViewController *)context {
    return [[TJPNavigationCoordinator sharedInstance] dispatchRequestWithModel:model inContext:context];
}

#pragma mark - 协议方法的默认实现（子类可重写）

- (TJPRouterCreationStrategy)creationStrategyForRoute:(NSString *)routeId {
    // 默认使用全局策略，子类可以为不同路由指定不同策略
    return self.creationStrategy;
}

- (BOOL)validateRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    // 默认只检查routeId非空，子类可以添加更复杂的验证逻辑
    return routeId.length > 0;
}

- (void)willNavigateToRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    // 默认空实现，子类可重写添加统计埋点等逻辑
}

- (void)didNavigateToRoute:(NSString *)routeId success:(BOOL)success {
    // 默认空实现，子类可重写添加统计分析等逻辑
}

- (NSDictionary *)processParametersForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    // 默认不处理，直接返回原参数，子类可重写添加通用参数等
    return parameters;
}

- (void)configureViewController:(UIViewController *)viewController forRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    // 默认的参数注入逻辑：通过KVC设置属性
    if (parameters) {
        for (NSString *key in parameters) {
            if ([viewController respondsToSelector:NSSelectorFromString(key)]) {
                @try {
                    [viewController setValue:parameters[key] forKey:key];
                } @catch (NSException *exception) {
                    NSLog(@"[%@] 参数注入失败: %@ - %@",
                          NSStringFromClass([self class]), key, exception.reason);
                }
            }
        }
    }
}

- (UIViewController *)createViewControllerForRoute:(NSString *)routeId
                                        parameters:(NSDictionary *)parameters {
    NSAssert(NO, @"子类必须实现 createViewControllerForRoute:parameters: 方法");
    return nil;
}

- (BOOL)handleNavigationLogicWithModel:(TJPNavigationModel *)model context:(UIViewController *)context {
    // 保持原有的协调器模式调用
    return [[TJPNavigationCoordinator sharedInstance] dispatchRequestWithModel:model inContext:context];
}

- (void)registerRoute:(NSString *)routeIdentifier selectorName:(NSString *)selectorName creationStrategy:(TJPRouterCreationStrategy)strategy {
    // 保持兼容，但新设计中推荐使用createViewControllerForRoute方法
    NSLog(@"[%@] registerRoute方法已废弃，请使用createViewControllerForRoute方法",
          NSStringFromClass([self class]));
}

- (void)registerRoutesFromConfig:(NSDictionary *)config {
    // 保持兼容，但新设计中推荐直接在子类中实现路由逻辑
    NSLog(@"[%@] registerRoutesFromConfig方法已废弃，请在子类中直接实现路由逻辑",
          NSStringFromClass([self class]));
}


@end






