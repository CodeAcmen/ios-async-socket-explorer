//
//  TJPBaseTableViewCellProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPBaseCellModelProtocol;


@protocol TJPBaseTableViewCellProtocol <NSObject>

@property (nonatomic, weak) id<TJPBaseCellModelProtocol> cellModel;



/// 配置cell数据
/// - Parameter cellModel: cellModel
- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel;



@optional
/// cell即将展示
/// - Parameter cellModel: cellModel
- (void)cellWillDisplay:(id<TJPBaseCellModelProtocol>) cellModel;


@end

NS_ASSUME_NONNULL_END
