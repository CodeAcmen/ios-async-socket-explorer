//
//  TJPViperBaseTableViewCell.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <UIKit/UIKit.h>

#import "TJPViperBaseCellModelProtocol.h"
#import "TJPViperBaseTableViewCellProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPViperBaseTableViewCell : UITableViewCell <TJPViperBaseTableViewCellProtocol>

@property (nonatomic, weak) id<TJPViperBaseCellModelProtocol> cellModel;

@property (nonatomic, strong) UIView *tjp_bottomLineView;


- (void)initializationChildUI;

@end

NS_ASSUME_NONNULL_END
