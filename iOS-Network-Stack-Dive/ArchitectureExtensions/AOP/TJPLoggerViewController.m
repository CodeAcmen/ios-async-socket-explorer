//
//  TJPLoggerViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import "TJPLoggerViewController.h"
#import "TJPLogAspectInterface.h"
#import "TJPLogger.h"
#import "TJPAspectCore.h"

@interface TJPLoggerViewController ()

@end

@implementation TJPLoggerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"轻量级切面日志演示";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 注册日志切面
    [self registerLoggingForMethods];
    
    // 调用需要日志记录的方法
    [self someMethodThatLogs];
}

- (void)registerLoggingForMethods {
    // 配置日志切面
    TJPLogConfig config;
    config.targetClass = [self class]; // 指定要增强的类
    config.targetSelector = @selector(someMethodThatLogs); // 指定要增强的方法
    
    [TJPAspectCore registerLogWithConfig:config
                                 trigger:(TJPLogTriggerBeforeMethod | TJPLogTriggerAfterMethod)
                                 handler:^(TJPLogModel *log) {
        [[TJPLogger shared] log:log];
    }];
}

- (void)someMethodThatLogs {
    NSLog(@"someMethodThatLogs started");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"执行一些业务逻辑...");
    });
    NSLog(@"someMethodThatLogs ended");

}





@end
