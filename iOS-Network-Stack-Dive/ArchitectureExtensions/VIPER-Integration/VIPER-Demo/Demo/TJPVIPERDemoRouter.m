//
//  TJPVIPERDemoRouter.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/28.
//

#import "TJPVIPERDemoRouter.h"
#import "TJPViperModuleProvider.h"
#import "TJPNavigationDefines.h"

@implementation TJPVIPERDemoRouter


- (UIViewController *)createViewControllerForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    
    // 根据策略选择创建方式
    TJPRouterCreationStrategy strategy = [self creationStrategyForRoute:routeId];
    
    switch (strategy) {
        case TJPRouterCreationStrategyDI:
            return [self createViewControllerWithDI:routeId parameters:parameters];
            
        case TJPRouterCreationStrategyHardcode:
            return [self createViewControllerWithHardcode:routeId parameters:parameters];
            
        case TJPRouterCreationStrategyFactory:
            return [self createViewControllerWithFactory:routeId parameters:parameters];
            
        default:
            NSLog(@"[ViperDemoRouter] 未知的创建策略: %ld", (long)strategy);
            return nil;
    }
}

/**
 * DI方式创建ViewController
 * 通过Typhoon等DI框架创建，适用于复杂的VIPER模块
 */
- (UIViewController *)createViewControllerWithDI:(NSString *)routeId parameters:(NSDictionary *)parameters {
    
    // VIPER Demo主页
    if ([routeId isEqualToString:@"viperDemo"]) {
        return [self.viperModuleProvider viperDemoViewController];
    }
    
    // VIPER Demo详情页
    if ([routeId isEqualToString:@"viperDemoDetail"]) {
        UIViewController *detailVC = [self.viperModuleProvider viperDemoDetailViewController];
        detailVC.hidesBottomBarWhenPushed = YES;
        return detailVC;
    }
    
    // 新闻详情页（假设通过DI创建）
    if ([routeId isEqualToString:@"newsDetail"]) {
        // 这里可能需要注入新闻模块的Provider
        return [self.viperModuleProvider viperDemoViewController]; // 示例用同一个VC
    }
    
    return nil;
}

/**
 * 硬编码方式创建ViewController
 * 直接通过类名创建，适用于简单的页面
 */
- (UIViewController *)createViewControllerWithHardcode:(NSString *)routeId
                                            parameters:(NSDictionary *)parameters {
    
    // 简单设置页
    if ([routeId isEqualToString:@"simpleSettings"]) {
        return [[NSClassFromString(@"SettingsViewController") alloc] init];
    }
    
    // Web页面
    if ([routeId isEqualToString:@"webView"]) {
        return [[NSClassFromString(@"WebViewController") alloc] init];
    }
    
    // 图片预览
    if ([routeId isEqualToString:@"imagePreview"]) {
        return [[NSClassFromString(@"ImagePreviewViewController") alloc] init];
    }
    
    // 用户资料页（硬编码方式）
    if ([routeId isEqualToString:@"userProfile"]) {
        return [[NSClassFromString(@"UserProfileViewController") alloc] init];
    }
    
    // 商品详情页（硬编码方式）
    if ([routeId isEqualToString:@"productDetail"]) {
        return [[NSClassFromString(@"ProductDetailViewController") alloc] init];
    }
    
    // 系统Alert
    if ([routeId isEqualToString:@"alert"]) {
        NSString *title = parameters[@"title"] ?: @"提示";
        NSString *message = parameters[@"message"] ?: @"";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        return alert;
    }
    
    return nil;
}

/**
 * 工厂模式创建ViewController
 * 根据参数动态选择创建方式，适用于需要灵活配置的场景
 */
- (UIViewController *)createViewControllerWithFactory:(NSString *)routeId
                                           parameters:(NSDictionary *)parameters {
    
    // 动态视图：根据参数选择不同的创建方式
    if ([routeId isEqualToString:@"dynamicView"]) {
        NSString *viewType = parameters[@"viewType"];
        if ([viewType isEqualToString:@"complex"]) {
            // 复杂视图用DI方式
            return [self.viperModuleProvider viperDemoViewController];
        } else {
            // 简单视图用硬编码方式
            return [[NSClassFromString(@"SimpleViewController") alloc] init];
        }
    }
    
    // 智能跳转：根据用户权限选择不同页面
    if ([routeId isEqualToString:@"smartJump"]) {
        BOOL isVip = [parameters[@"isVip"] boolValue];
        if (isVip) {
            return [[NSClassFromString(@"VipViewController") alloc] init];
        } else {
            return [[NSClassFromString(@"NormalViewController") alloc] init];
        }
    }
    
    return nil;
}

#pragma mark - 重写协议方法，自定义路由行为

- (TJPRouterCreationStrategy)creationStrategyForRoute:(NSString *)routeId {
    
    // 为不同的路由指定不同的创建策略
    
    // VIPER相关页面使用DI方式
    if ([routeId isEqualToString:@"viperDemo"] ||
        [routeId isEqualToString:@"viperDemoDetail"] ||
        [routeId isEqualToString:@"newsDetail"]) {
        return TJPRouterCreationStrategyDI;
    }
    
    // 简单页面使用硬编码方式
    if ([routeId isEqualToString:@"simpleSettings"] ||
        [routeId isEqualToString:@"webView"] ||
        [routeId isEqualToString:@"imagePreview"] ||
        [routeId isEqualToString:@"userProfile"] ||
        [routeId isEqualToString:@"productDetail"] ||
        [routeId isEqualToString:@"alert"]) {
        return TJPRouterCreationStrategyHardcode;
    }
    
    // 动态页面使用工厂模式
    if ([routeId isEqualToString:@"dynamicView"] ||
        [routeId isEqualToString:@"smartJump"]) {
        return TJPRouterCreationStrategyFactory;
    }
    
    // 其他使用默认策略
    return [super creationStrategyForRoute:routeId];
}

- (BOOL)validateRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    
    // 自定义验证逻辑
    
    // 详情页必须有ID参数
    if ([routeId isEqualToString:@"viperDemoDetail"]) {
        return parameters[@"detailId"] != nil;
    }
    
    if ([routeId isEqualToString:@"newsDetail"]) {
        return parameters[@"newsId"] != nil;
    }
    
    if ([routeId isEqualToString:@"userProfile"]) {
        return parameters[@"userId"] != nil;
    }
    
    if ([routeId isEqualToString:@"productDetail"]) {
        return parameters[@"productId"] != nil;
    }
    
    // WebView必须有URL参数
    if ([routeId isEqualToString:@"webView"]) {
        return parameters[@"url"] != nil;
    }
    
    // 工厂模式页面需要特定参数
    if ([routeId isEqualToString:@"dynamicView"]) {
        return parameters[@"viewType"] != nil;
    }
    
    // 其他使用默认验证
    return [super validateRoute:routeId parameters:parameters];
}

- (void)willNavigateToRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    // 导航前的统计埋点
    NSLog(@"[Analytics] 准备导航到: %@, 参数: %@", routeId, parameters);
    
    // 可以在这里添加具体的统计代码
    // [Analytics track:@"route_start" properties:@{@"route": routeId, @"params": parameters}];
}

- (void)didNavigateToRoute:(NSString *)routeId success:(BOOL)success {
    // 导航完成后的统计
    NSLog(@"[Analytics] 导航完成: %@, 成功: %@", routeId, success ? @"YES" : @"NO");
    
    // 可以在这里添加具体的统计代码
    // [Analytics track:@"route_end" properties:@{@"route": routeId, @"success": @(success)}];
}

- (NSDictionary *)processParametersForRoute:(NSString *)routeId parameters:(NSDictionary *)parameters {
    
    // 参数预处理：添加通用参数
    NSMutableDictionary *processedParams = [parameters mutableCopy] ?: [NSMutableDictionary dictionary];
    
    // 添加通用参数
    processedParams[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    processedParams[@"source"] = @"ViperDemo";
    
    // 特殊路由的参数处理
    if ([routeId isEqualToString:@"viperDemoDetail"]) {
        // 为详情页添加默认标题
        if (!processedParams[@"title"]) {
            processedParams[@"title"] = @"VIPER详情页";
        }
    }
    
    if ([routeId isEqualToString:@"newsDetail"]) {
        // 新闻详情页参数处理
        if (!processedParams[@"title"]) {
            processedParams[@"title"] = @"新闻详情";
        }
    }
    
    return processedParams;
}

- (void)configureViewController:(UIViewController *)viewController
                       forRoute:(NSString *)routeId
                     parameters:(NSDictionary *)parameters {
    
    // 先调用父类的默认配置（KVC参数注入）
    [super configureViewController:viewController forRoute:routeId parameters:parameters];
    
    // 自定义配置逻辑
    
    // 详情页隐藏底部TabBar
    if ([routeId isEqualToString:@"viperDemoDetail"] ||
        [routeId isEqualToString:@"newsDetail"] ||
        [routeId isEqualToString:@"userProfile"] ||
        [routeId isEqualToString:@"productDetail"]) {
        viewController.hidesBottomBarWhenPushed = YES;
    }
    
    // 设置导航栏标题
    if (parameters[@"title"]) {
        viewController.title = parameters[@"title"];
    }
    
    // WebView特殊配置
    if ([routeId isEqualToString:@"webView"]) {
        viewController.title = @"网页";
        // 可以在这里设置WebView的其他属性
    }
    
    // 设置页面配置
    if ([routeId isEqualToString:@"simpleSettings"]) {
        viewController.title = @"设置";
    }
}


@end
