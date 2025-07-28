//
//  TJPViewPushHandler.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViewPushHandler.h"
#import "TJPNavigationModel.h"
#import "TJPNetworkDefine.h"

@implementation TJPViewPushHandler


- (void)dealloc {
    NSLog(@"TJPViewPushHandler dealloc: %p", self);
}

- (BOOL)handleRequestWithModel:(TJPNavigationModel *)model context:(UIViewController *)context {
    UIViewController *targetVC = model.targetVC;
    
    if (!targetVC) {
        NSLog(@"[ViewPushHandler] Router 未提供 targetVC，跳转失败：%@", model.routeId);
        return NO;
    }

    if (context.navigationController) {
        [context.navigationController pushViewController:targetVC animated:model.animated];
        return YES;
    } else {
        NSLog(@"[ViewPushHandler] 当前上下文无 NavigationController");
        return NO;
    }
}


@end
