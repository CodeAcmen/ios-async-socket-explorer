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
#import "TJPMessageFactory.h"
#import "TJPLogManager.h"

@interface AppDelegate ()

@property (nonatomic, strong) TJPViewPushHandler *pushHandler;
@property (nonatomic, strong) TJPViewPresentHandler *presentHandler;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 0.自动注册所有消息类型  必须
    [TJPMessageFactory load];
    
    // 控制台输出
    [[TJPLogManager sharedManager] setDebugLoggingEnabled:YES];
    [TJPLogManager sharedManager].minLogLevel = TJPLogLevelDebug;

    // 设置导航跳转处理容器
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


