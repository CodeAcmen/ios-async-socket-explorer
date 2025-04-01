//
//  TJPVIPERDemoCellModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoCellModel.h"
#import "TJPNavigationModel.h"


@implementation TJPVIPERDemoCellModel


- (NSString *)cellName {
    return @"TJPVIPERDemoCell";
}

- (CGFloat)cellHeight {
    return 50;
}


- (TJPNavigationModel *)navigationModelForCell {
    NSDictionary *params = @{
        @"viewControllerClass": @"TJPVIPERDemoDetailViewController",
        @"navigationType": @(TJPNavigationTypePush),
        @"detailId": self.detailId,
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };

    return [TJPNavigationModel modelWithRouteId:@"demo/detail"
                                    parameters:params];
}

@end
