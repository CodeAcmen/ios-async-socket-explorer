//
//  TJPBaseTableView.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//  适用于MVVM/VIPER的基础UI组件

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPBaseCellModelProtocol, TJPBaseSectionModelProtocol, TJPBaseTableViewLoadingProtocol;

@protocol TJPBaseTableViewDelegate <NSObject>
@optional
- (void)tjpEmptyViewDidTapped:(UIView *)view;
- (void)tjpTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tjpTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;


@end

@interface TJPBaseTableView : UITableView

@property (nonatomic, weak) id<TJPBaseTableViewDelegate> tjpBaseTableViewDelegate;

/// Section 模型数组，每个 Section 包含 cellModels
@property (nonatomic, strong) NSArray<id<TJPBaseSectionModelProtocol>> *sectionModels;

/// 存储 CellModel 数据
@property (nonatomic, strong) NSMutableArray<id<TJPBaseCellModelProtocol>> *cellModels;


/// 动画对象（默认提供旋转动画）
@property (nonatomic, strong) id<TJPBaseTableViewLoadingProtocol> loadingAnimation;

/**
 * 刷新TableView数据
 * @param sections 装载Section模型的数据  cell模型的数组cellModels为sections中的属性
 */
- (void)reloadDataWithSectionModels:(NSArray<id<TJPBaseSectionModelProtocol>> *)sections;
//- (void)reloadDataWithCellModels:(NSArray<id<TJPBaseCellModelProtocol>> *)cellModels;

/**
 * 局部刷新TableView数据
 * @param indexPaths 需要刷新的行的索引路径数组
 * @param animation 刷新时的动画效果
 */
- (void)tableReloadRowsWithIndexPaths:(NSArray<NSIndexPath *> *)indexPaths animation:(UITableViewRowAnimation)animation;


/// 刷新所有数据（支持 Diff 策略）
- (void)reloadDataWithSectionModels:(NSArray<id<TJPBaseSectionModelProtocol>> *)sections;

/// 刷新某个 section
- (void)reloadSection:(NSInteger)section withAnimation:(UITableViewRowAnimation)animation;


/// 配置下拉刷新
- (void)configurePullDownRefreshControlWithTarget:(id)target pullDownAction:(SEL)pullDownAction;
/// 配置上拉加载更多
- (void)configurePullUpRefreshControlWithTarget:(id)target pullUpAction:(SEL)pullUpAction;
/// 结束刷新
- (void)endRefreshing;
/// 没有更多数据
- (void)noMoreData;



/// 空白样式 允许重写
- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView;
/// 展示空白数据
- (void)showEmptyData;
/// 隐藏空白数据
- (void)hideEmptyData;





@end

NS_ASSUME_NONNULL_END
