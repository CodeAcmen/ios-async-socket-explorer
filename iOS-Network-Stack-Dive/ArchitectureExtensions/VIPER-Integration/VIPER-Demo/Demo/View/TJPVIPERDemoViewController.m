//
//  TJPVIPERDemoViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoViewController.h"
#import "TJPFPSLabel.h"


@interface TJPVIPERDemoViewController ()

@end

@implementation TJPVIPERDemoViewController

- (void)dealloc {
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    TJPFPSLabel *fpsLabel = [[TJPFPSLabel alloc] initWithFrame:CGRectMake(20, 100, 80, 30)];
    [self.view addSubview:fpsLabel];
    
    self.title = @"多类型Feed流应用 - VIPER架构实战";
    self.view.backgroundColor = [UIColor whiteColor];
}


@end
