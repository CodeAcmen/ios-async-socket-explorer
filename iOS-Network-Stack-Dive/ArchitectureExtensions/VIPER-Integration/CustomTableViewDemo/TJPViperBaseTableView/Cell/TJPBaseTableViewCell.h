//
//  TJPBaseTableViewCell.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <UIKit/UIKit.h>

#import "TJPBaseCellModelProtocol.h"
#import "TJPBaseTableViewCellProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPBaseTableViewCell : UITableViewCell <TJPBaseTableViewCellProtocol>

@property (nonatomic, weak) id<TJPBaseCellModelProtocol> cellModel;

@property (nonatomic, strong) UIView *tjp_bottomLineView;


- (void)initializationChildUI;

@end

NS_ASSUME_NONNULL_END
