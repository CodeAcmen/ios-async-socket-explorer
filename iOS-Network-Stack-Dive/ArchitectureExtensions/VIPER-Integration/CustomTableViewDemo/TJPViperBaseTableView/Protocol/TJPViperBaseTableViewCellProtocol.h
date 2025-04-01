//
//  TJPViperBaseTableViewCellProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseCellModelProtocol;


@protocol TJPViperBaseTableViewCellProtocol <NSObject>

@property (nonatomic, weak) id<TJPViperBaseCellModelProtocol> cellModel;



/// 配置cell数据
/// - Parameter cellModel: cellModel
- (void)configureWithModel:(id<TJPViperBaseCellModelProtocol>)cellModel;



@optional
/// cell即将展示
/// - Parameter cellModel: cellModel
- (void)cellWillDisplay:(id<TJPViperBaseCellModelProtocol>) cellModel;


@end

NS_ASSUME_NONNULL_END
