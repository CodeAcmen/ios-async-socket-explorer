//
//  AppDelegate.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/17.
//

#import "AppDelegate.h"
#import "HomeViewController.h"


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[[HomeViewController alloc] init]];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}



@end
