//
//  TJPVIPERDemoCell.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPViperBaseTableViewCell.h"
#import "TJPVIPERDemoCellModel.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPVIPERDemoCell : TJPViperBaseTableViewCell
@property (nonatomic, weak) TJPVIPERDemoCellModel *cellModel;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end

NS_ASSUME_NONNULL_END
