//
//  TJPVIPERDemoPresenter.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/28.
//

#import "TJPVIPERDemoPresenter.h"
#import "TJPNavigationModel.h"

@implementation TJPVIPERDemoPresenter

#pragma mark - 实现模板方法

/**
 * 重写模板方法：处理VIPER Demo模块相关的CellModel
 */
- (TJPNavigationModel *)buildNavigationModelFromCellModel:(id)cellModel {
    
    if (!cellModel) {
        return nil;
    }
    
    // 处理TJPVIPERDemoCellModel
    if ([cellModel isKindOfClass:NSClassFromString(@"TJPVIPERDemoCellModel")]) {
        return [self buildVIPERDemoNavigationModel:cellModel];
    }
    
    // 处理其他本模块关心的CellModel类型
    // 例如：如果这个Presenter也需要处理新闻Cell
    if ([cellModel isKindOfClass:NSClassFromString(@"TJPNewsCellModel")]) {
        return [self buildNewsNavigationModel:cellModel];
    }
    
    // 对于不处理的类型，调用父类的默认实现
    return [super buildNavigationModelFromCellModel:cellModel];
}

/**
 * 构建VIPER Demo的NavigationModel
 */
- (TJPNavigationModel *)buildVIPERDemoNavigationModel:(id)cellModel {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    // 通过KVC安全地获取属性值
    if ([cellModel respondsToSelector:@selector(detailId)]) {
        id detailId = [(NSObject *)cellModel valueForKey:@"detailId"];
        if (detailId) parameters[@"detailId"] = detailId;
    }
    
    if ([cellModel respondsToSelector:@selector(title)]) {
        id title = [(NSObject *)cellModel valueForKey:@"title"];
        if (title) parameters[@"title"] = title;
    }
    
    if ([cellModel respondsToSelector:@selector(subtitle)]) {
        id subtitle = [(NSObject *)cellModel valueForKey:@"subtitle"];
        if (subtitle) parameters[@"subtitle"] = subtitle;
    }
    
    // 添加通用参数
    parameters[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    TJPNavigationModel *model = [TJPNavigationModel modelWithRouteId:@"viperDemoDetail" parameters:[parameters copy] routeType:TJPNavigationRouteTypeViewPush];
    model.animated = YES;
    
    return model;
}

/**
 * 构建新闻的NavigationModel（如果这个Presenter也处理新闻）
 */
- (TJPNavigationModel *)buildNewsNavigationModel:(id)cellModel {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if ([cellModel respondsToSelector:@selector(newsId)]) {
        id newsId = [(NSObject *)cellModel valueForKey:@"newsId"];
        if (newsId) parameters[@"newsId"] = newsId;
    }
    
    if ([cellModel respondsToSelector:@selector(title)]) {
        id title = [(NSObject *)cellModel valueForKey:@"title"];
        if (title) parameters[@"title"] = title;
    }
    
    TJPNavigationModel *model = [TJPNavigationModel modelWithRouteId:@"newsDetail" parameters:[parameters copy] routeType:TJPNavigationRouteTypeViewPush];
    model.animated = YES;
    
    return model;
}

@end
