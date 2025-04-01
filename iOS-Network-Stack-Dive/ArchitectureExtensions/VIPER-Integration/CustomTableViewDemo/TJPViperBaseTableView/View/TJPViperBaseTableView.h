//
//  TJPViperBaseTableView.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseCellModelProtocol;

@protocol TJPViperBaseTableViewDelegate <NSObject>
@optional
- (void)tjpEmptyViewDidTapped:(UIView *)view;
- (void)tjpTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tjpTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;


@end

@interface TJPViperBaseTableView : UITableView

@property (nonatomic, weak) id<TJPViperBaseTableViewDelegate> tjpViperBaseTableViewDelegate;

/// 存储 CellModel 数据
@property (nonatomic, strong) NSMutableArray<id<TJPViperBaseCellModelProtocol>> *cellModels;
/// 刷新TableView数据
/// - Parameter cellModels: 装载cell模型的数组
- (void)reloadDataWithCellModels:(NSArray<id<TJPViperBaseCellModelProtocol>> *)cellModels;
/// 局部刷新TableView数据
/// - Parameters:
///   - indexPaths: 需要刷新的行的索引路径数组
///   - animation: 刷新时的动画效果
- (void)tableReloadRowsWithIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                       animation:(UITableViewRowAnimation)animation;


/// 配置下拉刷新
- (void)configurePullDownRefreshControlWithTarget:(id)target pullDownAction:(SEL)pullDownAction;
/// 配置上拉加载更多
- (void)configurePullUpRefreshControlWithTarget:(id)target pullUpAction:(SEL)pullUpAction;
/// 结束刷新
- (void)endRefreshing;


/// 注册cell
- (void)registerCells;


/// 空白样式 允许重写
- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView;
/// 展示空白数据
- (void)showEmptyData;
/// 隐藏空白数据
- (void)hideEmptyData;





@end

NS_ASSUME_NONNULL_END
