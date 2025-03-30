//
//  TJPViperBaseCellModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPViperBaseCellModel.h"

@interface TJPViperBaseCellModel ()

// 用于缓存 cell 高度
@property (nonatomic, assign) CGFloat cachedHeight;

@end

@implementation TJPViperBaseCellModel

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
    return @"TJPViperBaseTableViewCell";
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

- (JZNavigationType)navigationTypeForModel {
    return JZNavigationTypePush;
}


#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
//**************************************************

@end
