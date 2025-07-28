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
    UIViewController *targetVC = model.targetVC;
    
    if (!targetVC) {
        NSLog(@"[ViewPresentHandler] Router 未提供 targetVC，跳转失败：%@", model.routeId);
        return NO;
    }

    if (context) {
        [context presentViewController:targetVC animated:YES completion:nil];
        return YES;
    } else {
        NSLog(@"[ViewPresentHandler] 当前上下文无 NavigationController");
        return NO;
    }
}

@end
