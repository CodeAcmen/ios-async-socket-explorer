//
//  TJPVIPERDemoDetailViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoDetailViewController.h"

@interface TJPVIPERDemoDetailViewController ()

@end

@implementation TJPVIPERDemoDetailViewController

- (void)dealloc {
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"VIPER DEMO详情页";
    self.view.backgroundColor = [UIColor whiteColor];
}



@end
