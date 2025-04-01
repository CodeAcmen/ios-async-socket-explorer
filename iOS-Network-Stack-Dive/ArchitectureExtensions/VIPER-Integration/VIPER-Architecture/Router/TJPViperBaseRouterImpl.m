//
//  TJPViperBaseRouterImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseRouterImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPNavigationModel.h"
#import "TJPNavigationDefines.h"

#import "TJPNavigationCoordinator.h"


@interface TJPViperBaseRouterImpl ()

@end


@implementation TJPViperBaseRouterImpl

- (void)dealloc {
    TJPLogDealloc();
}

#pragma mark - TJPViperBaseRouterHandlerProtocol
- (BOOL)handleNavigationLogicWithModel:(TJPNavigationModel *)model context:(UIViewController *)context {
    return [[TJPNavigationCoordinator sharedInstance] dispatchRequestWithModel:model routeType:TJPNavigationRouteTypeViewPush inContext:context];
}


@end






