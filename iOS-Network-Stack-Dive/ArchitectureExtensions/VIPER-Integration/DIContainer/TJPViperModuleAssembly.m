//
//  TJPViperModuleAssembly.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperModuleAssembly.h"
#import "TJPViperModuleProvider.h"
#import "AppDelegate.h"
#import "HomeViewController.h"


#import "TJPViperBasePresenterImpl.h"
#import "TJPViperBaseInteractorImpl.h"
#import "TJPViperBaseRouterImpl.h"


#import "TJPVIPERDemoViewController.h"
#import "TJPVIPERDemoInteractorImpl.h"


@interface TJPViperModuleAssembly () <TJPViperModuleProvider>

@end

@implementation TJPViperModuleAssembly


- (UIResponder *)appDelegate {
    return [TyphoonDefinition withClass:[AppDelegate class] configuration:^(TyphoonDefinition *definition) {
        [definition injectProperty:@selector(homeViewController) with:[self tjpHomeNavViewController]];
//        [definition injectProperty:@selector(jzIMService) with:self.jzViperBaseModuleProvider.jzIMService];
    }];
}


- (UINavigationController *)tjpHomeNavViewController {
    return [TyphoonDefinition withClass:[UINavigationController class] configuration:^(TyphoonDefinition *definition) {
        [definition useInitializer:@selector(initWithRootViewController:) parameters:^(TyphoonMethod *initializer) {
            [initializer injectParameterWith:[self tjpHomeViewController]];
        }];
    }];
}

- (UIViewController *)tjpHomeViewController {
    return [TyphoonDefinition withClass:[HomeViewController class] configuration:^(TyphoonDefinition *definition) {
        [definition injectProperty:@selector(hidesBottomBarWhenPushed) with:@(NO)];
        [definition injectProperty:@selector(tjpViperModuleProvider) with:self];
    }];
}


- (UIViewController *)viperDemoViewController {
    return [TyphoonDefinition withClass:[TJPVIPERDemoViewController class] configuration:^(TyphoonDefinition *definition) {
        [definition injectProperty:@selector(basePresenter) with:self.viperDemoPresenter];
    }];
    
}

- (id)viperDemoRouter {
    return [TyphoonDefinition withClass:[TJPViperBaseRouterImpl class] configuration:^(TyphoonDefinition *definition) {
        //路由一般注入Typhoon不同模块定义类的接口 如TJPViperModuleProvider
    }];
}

- (id)viperDemoPresenter {
    return [TyphoonDefinition withClass:[TJPViperBasePresenterImpl class] configuration:^(TyphoonDefinition *definition) {
        [definition injectProperty:@selector(baseInteractor) with:self.viperDemoInteractor];
        [definition injectProperty:@selector(baseRouter) with:self.viperDemoRouter];
    }];
}

- (id)viperDemoInteractor {
    return [TyphoonDefinition withClass:[TJPVIPERDemoInteractorImpl class] configuration:^(TyphoonDefinition *definition) {
        //interactor层一般都是注入网络框架  缓存框架等工具框架
    }];
}


@end
