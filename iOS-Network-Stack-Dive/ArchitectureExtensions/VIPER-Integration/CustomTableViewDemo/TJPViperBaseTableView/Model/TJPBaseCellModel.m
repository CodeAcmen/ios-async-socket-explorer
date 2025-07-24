//
//  TJPBaseCellModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPBaseCellModel.h"
#import "TJPNavigationModel.h"

@interface TJPBaseCellModel ()

// 用于缓存 cell 高度
@property (nonatomic, assign) CGFloat cachedHeight;

@end

@implementation TJPBaseCellModel

#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        self.tjp_showBottomLine = YES;
        // 缓存高度为 -1，表示未计算过
        self.cachedHeight = -1;
    }
    return self;
}
//**************************************************
- (NSString *)cellName {
    return @"TJPBaseTableViewCell";
}

- (CGFloat)cellHeight {
    if (self.cachedHeight < 0) {
        // 如果缓存的高度没有被计算，进行计算
        self.cachedHeight = [self calculateCellHeight];
    }
    return self.cachedHeight; 
}

- (CGFloat)calculateCellHeight {
    
    return 44;
}

// 示例
- (TJPNavigationModel *)navigationModelForCell {
//    NSDictionary *params = @{
//        @"viewControllerClass": @"MessageDetailViewController",
//        @"navigationType": @(TJPNavigationTypePush),
//        @"messageId": self.messageId,
//        @"timestamp": @([[NSDate date] timeIntervalSince1970])
//    };
//    
//    return [TJPNavigationModel modelWithRouteID:@"message/detail"
//                                    parameters:params];
    
    return [TJPNavigationModel modelWithRouteId:@"" parameters:@{}];
}


// 已废弃
- (TJPNavigationType)navigationTypeForModel {
    return TJPNavigationTypePush;
}




#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
//**************************************************

@end

