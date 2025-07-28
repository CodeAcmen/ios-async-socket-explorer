//
//  TJPNavigationModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPNavigationModel.h"

@implementation TJPNavigationModel

+ (instancetype)modelWithRouteId:(NSString *)routeId parameters:(NSDictionary *)params routeType:(TJPNavigationRouteType)routeType {
    TJPNavigationModel *model = [[TJPNavigationModel alloc] init];
    model.routeId = routeId;
    model.parameters = params ?: @{};
    model.routeType = routeType;
    model.timestamp = [[NSDate date] timeIntervalSince1970];
    
    return model;
}

@end
