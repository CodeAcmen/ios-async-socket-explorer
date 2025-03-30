//
//  TJPLoggerViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import "TJPLoggerViewController.h"
#import "TJPLoggerManager.h"



@interface TJPLoggerViewController ()



@end

@implementation TJPLoggerViewController

- (NSString *)greeting:(NSString *)name {
    return name;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"轻量级切面日志演示";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 注册日志切面
    [self registerLoggingForMethods];
    
    // 调用需要日志记录的方法
    [self testNoParams];
//    [self testOneParam:@"小明"];
//    [self testTwoParams:@"小红" age:18];
}

- (void)registerLoggingForMethods {
    
    [TJPLoggerManager registerLogForTargetClass:[self class] targetSelector:@selector(testNoParams) triggers:(TJPLogTriggerBeforeMethod | TJPLogTriggerAfterMethod) outputs:(TJPLogOutputOptionConsole)];
    
    [TJPLoggerManager registerLogForTargetClass:[self class] targetSelector:@selector(testOneParam:) triggers:(TJPLogTriggerBeforeMethod | TJPLogTriggerAfterMethod) outputs:(TJPLogOutputOptionConsole)];

}

- (void)testNoParams {
    NSLog(@"someMethodThatLogs started");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"after 1.5s someMethodThatLogs...");
    });
    NSLog(@"someMethodThatLogs ended");

}

- (void)testOneParam:(NSString *)name {
    NSLog(@"testOneParam called with name = %@", name);
}


- (void)testTwoParams:(NSString *)name age:(NSInteger)age {
    NSLog(@"testTwoParams called - name: %@, age: %ld", name, (long)age);
}

- (void)testThreeParams:(NSString *)name age:(NSInteger)age city:(NSString *)city {
    NSLog(@"testThreeParams - name: %@, age: %ld, city: %@", name, (long)age, city);
}

- (NSString *)testReturnString {
    NSLog(@"testReturnString called");
    return @"Hello, Log!";
}

- (NSInteger)testAdd:(NSInteger)a b:(NSInteger)b {
    NSLog(@"testAdd called with a = %ld, b = %ld", (long)a, (long)b);
    return a + b;
}


- (NSString *)processData:(NSData *)data count:(int)count {
    NSLog(@"processData data - count: %@, age: %ld", data, (long)count);
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


@end

