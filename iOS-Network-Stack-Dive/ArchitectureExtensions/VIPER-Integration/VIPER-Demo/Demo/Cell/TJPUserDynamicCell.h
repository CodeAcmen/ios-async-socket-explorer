//
//  TJPUserDynamicCell.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseTableViewCell.h"
#import "TJPUserDynamicCellModel.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPUserDynamicCell : TJPBaseTableViewCell

@property (nonatomic, weak) TJPUserDynamicCellModel *cellModel;


@end

NS_ASSUME_NONNULL_END
