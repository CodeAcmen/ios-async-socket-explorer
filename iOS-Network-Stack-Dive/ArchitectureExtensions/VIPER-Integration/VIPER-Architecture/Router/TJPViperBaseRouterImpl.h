//
//  TJPViperBaseRouterImpl.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  提供通用的路由功能和扩展点，子类通过重写相关方法实现具体的路由逻辑

#import <UIKit/UIKit.h>
#import "TJPViperBaseRouterHandlerProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@class TJPViperDefaultErrorHandler;

/**
 * - Base类：定义通用的跳转规则、参数处理、生命周期管理等
 * - 子类：只需要关心具体ViewController的创建逻辑
 * - 协调器模式：通过TJPNavigationCoordinator统一分发路由请求
 */
@interface TJPViperBaseRouterImpl : NSObject <TJPViperBaseRouterHandlerProtocol>
// 创建策略
@property (nonatomic, assign) TJPRouterCreationStrategy creationStrategy;
// 错误处理
@property (nonatomic, strong, readonly) TJPViperDefaultErrorHandler *errorHandler;
// 是否启用导航日志
@property (nonatomic, assign) BOOL enableNavigationLog;
// 是否启用导航动画
@property (nonatomic, assign) BOOL enableNavigationAnimation;

//泛型，通用的Provider存储，子类可以转换为具体类型
@property (nonatomic, strong) id moduleProvider;


// 初始化方法
- (instancetype)initWithModuleProvider:(id)moduleProvider;


- (BOOL)navigateToRouteWithNavigationModel:(TJPNavigationModel *)model fromContext:(UIViewController *)context animated:(BOOL)animated;


/// 子类必须实现：根据路由标识创建ViewController
- (UIViewController *)createViewControllerForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;

// 路由注册
- (void)registerRoute:(NSString *)routeIdentifier selectorName:(NSString *)selectorName creationStrategy:(TJPRouterCreationStrategy)strategy;

// 批量注册路由
- (void)registerRoutesFromConfig:(NSDictionary *)config;

@end

NS_ASSUME_NONNULL_END
