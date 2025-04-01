//
//  AppDelegate.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//

#import "AppDelegate.h"
#import "TJPNavigationCoordinator.h"
#import "HomeViewController.h"
#import "TJPViewPushHandler.h"
#import "TJPViewPresentHandler.h"

@interface AppDelegate ()

@property (nonatomic, strong) TJPViewPushHandler *pushHandler;
@property (nonatomic, strong) TJPViewPresentHandler *presentHandler;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self setupNavigationCoordinator];
    
    [self setupWindow];
    
    return YES;
}

- (void)setupNavigationCoordinator {
    TJPNavigationCoordinator *coordinator = [TJPNavigationCoordinator sharedInstance];
    
    self.pushHandler = [TJPViewPushHandler new];
    self.presentHandler = [TJPViewPresentHandler new];

    
    // 注册标准处理器
    [coordinator registerHandler:self.pushHandler forRouteType:TJPNavigationRouteTypeViewPush];
    
    [coordinator registerHandler:self.presentHandler forRouteType:TJPNavigationRouteTypeViewPresent];
//
//    // 注册服务处理器
//    [coordinator registerHandler:[TJPServiceHandler handlerWithServiceCenter:self.serviceCenter]
//                       forRouteType:TJPNavigationRouteTypeServiceCall];
}

- (void)setupWindow {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    self.window.rootViewController = self.homeViewController; //[[UINavigationController alloc] initWithRootViewController:[[HomeViewController alloc] init]];
    
    [self.window makeKeyAndVisible];
}



@end


