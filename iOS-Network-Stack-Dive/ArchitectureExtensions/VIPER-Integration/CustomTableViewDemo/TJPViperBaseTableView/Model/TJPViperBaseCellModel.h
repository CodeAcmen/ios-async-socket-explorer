//
//  TJPViperBaseCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>
#import "TJPViperBaseCellModelProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPViperBaseCellModel : NSObject <TJPViperBaseCellModelProtocol>

@property (nonatomic, strong) RACCommand<id, NSObject*>* selectedCommand;


@property (nonatomic, assign) BOOL tjp_showBottomLine;


- (TJPNavigationModel *)navigationModelForCell;


/// 子类实现的计算Cell高度方法
- (CGFloat)calculateCellHeight;

@end

NS_ASSUME_NONNULL_END
