//
//  TJPViewPresentHandler.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPViewPresentHandler.h"
#import "TJPNavigationModel.h"
#import "TJPNetworkDefine.h"


@implementation TJPViewPresentHandler


- (BOOL)handleRequestWithModel:(TJPNavigationModel *)model context:(UIViewController *)context {
    // 参数解析
    NSString *vcClassName = model.parameters[@"viewControllerClass"];
    if (!vcClassName) return NO;
    
    Class vcClass = NSClassFromString(vcClassName);
    if (![vcClass isSubclassOfClass:[UIViewController class]]) {
        TJPLOG_ERROR(@"Invalid view controller class: %@", vcClassName);
        return NO;
    }
    
    // 创建实例
    UIViewController *targetVC = [[vcClass alloc] init];
    if (!targetVC) return NO;
    
    // 执行跳转
    if (context.navigationController) {
        [context.navigationController pushViewController:targetVC animated:YES];
        return YES;
    }
    
    return NO;
}


@end
