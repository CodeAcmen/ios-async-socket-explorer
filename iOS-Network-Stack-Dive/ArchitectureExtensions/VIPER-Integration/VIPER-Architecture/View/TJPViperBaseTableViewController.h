//
//  TJPViperBaseTableViewController.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

/**
 * 基础TableView视图控制器
 *
 * 职责：
 * - UI管理和视图生命周期
 * - 数据协调和分页控制
 * - 缓存管理
 * - 错误处理
 *
 * 抽离的组件：
 * - 状态机：TJPViewControllerStateMachine
 * - 可插拔组件：缓存、错误处理、刷新控件
 */

#import <UIKit/UIKit.h>
#import "TJPViperBaseViewControllerProtocol.h"
#import "TJPBaseTableView.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBasePresenterProtocol;
@class TJPViewControllerStateMachine;

@interface TJPViperBaseTableViewController : UIViewController <TJPViperBaseViewControllerProtocol>
// 核心组件
@property (nonatomic, strong) TJPBaseTableView *tableView;
//vc->强引用presenter
@property (nonatomic, strong) id<TJPViperBasePresenterProtocol> basePresenter;

// 状态管理
@property (nonatomic, strong, readonly) TJPViewControllerStateMachine *stateMachine;


/// 是否启用下拉刷新
@property (nonatomic, assign) BOOL shouldEnablePullDownRefresh;
/// 是否启用上拉加载更多
@property (nonatomic, assign) BOOL shouldEnablePullUpRefresh;

/// 重复请求管理
@property (nonatomic, assign) BOOL shouldPreventDuplicateRequests;

// 分页信息
@property (nonatomic, assign, readonly) NSInteger currentPage;
@property (nonatomic, assign, readonly) NSInteger totalPage;


// 子类可重写的方法
- (void)setupTableViewStyle;
- (void)configureInitialState;

- (NSString *)cacheKeyForPage:(NSInteger)page;
- (NSString *)requestKeyForPage:(NSInteger)page;

/// 额外操作TableViewUI方法
- (void)updateTableViewUIForExtensionOperate;

/// 配置刷新控件
- (void)configureRefreshControls;

// 数据操作方法
- (void)reloadData;
- (void)loadDataForPage:(NSInteger)page;
- (void)refreshData;
- (void)loadMoreData;


@end

NS_ASSUME_NONNULL_END
