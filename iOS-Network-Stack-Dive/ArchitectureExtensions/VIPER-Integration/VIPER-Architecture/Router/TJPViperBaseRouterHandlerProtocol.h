//
//  TJPViperBaseRouterHandlerProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  定义了Router层的标准接口和职责

#import <Foundation/Foundation.h>
#import "TJPNavigationDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPNavigationModel;
@protocol TJPViperModuleProvider;

@protocol TJPViperBaseRouterHandlerProtocol <NSObject>


@optional
/**
 * 处理导航逻辑
 * @param model 导航模型
 * @param context 当前上下文
 * @return 是否导航成功
 */
- (BOOL)handleNavigationLogicWithModel:(TJPNavigationModel *)model context:(UIViewController *)context;

/**
 * 处理导航请求
 * @param model 导航模型
 * @param context 当前上下文
 * @return 是否处理成功
 */
- (BOOL)handleRequestWithModel:(TJPNavigationModel *)model context:(UIViewController *)context;

/**
 * 完整的路由跳转方法
 * @param model 导航模型
 * @param context 当前上下文ViewController
 * @param animated 是否显示动画
 * @return 是否处理成功
 */
- (BOOL)navigateToRouteWithNavigationModel:(TJPNavigationModel *)model fromContext:(UIViewController *)context animated:(BOOL)animated;


// 根据路由标识创建对应的ViewController
- (UIViewController *)createViewControllerForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;

// 获取指定路由的创建策略
- (TJPRouterCreationStrategy)creationStrategyForRoute:(NSString *)routeId;
// 验证路由参数是否有效
- (BOOL)validateRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;

// 即将开始导航时调用
- (void)willNavigateToRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;
// 导航完成后调用
- (void)didNavigateToRoute:(NSString *)routeId success:(BOOL)success;

// 预处理路由参数
- (NSDictionary *)processParametersForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;
// 配置ViewController
- (void)configureViewController:(UIViewController *)viewController forRoute:(NSString *)routeId parameters:(NSDictionary *)parameters;


@end

NS_ASSUME_NONNULL_END
