//
//  TJPBaseCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>
#import "TJPBaseCellModelProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPBaseCellModel : NSObject <TJPBaseCellModelProtocol>

/// 选中Cell信号
@property (nonatomic, strong) RACCommand<id, NSObject*>* selectedCommand;
/// 是否显示底部线条
@property (nonatomic, assign) BOOL tjp_showBottomLine;


/// Cell名称
- (NSString *)cellName;
/// Cell高度
- (CGFloat)cellHeight;
/// 子类实现的计算Cell高度方法
- (CGFloat)calculateCellHeight;

@end

NS_ASSUME_NONNULL_END
