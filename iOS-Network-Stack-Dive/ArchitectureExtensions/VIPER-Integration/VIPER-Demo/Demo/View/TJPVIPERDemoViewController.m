//
//  TJPVIPERDemoViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoViewController.h"

@interface TJPVIPERDemoViewController ()

@end

@implementation TJPVIPERDemoViewController

- (void)dealloc {
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"多类型Feed流应用 - VIPER架构实战";
    self.view.backgroundColor = [UIColor whiteColor];
}


@end
