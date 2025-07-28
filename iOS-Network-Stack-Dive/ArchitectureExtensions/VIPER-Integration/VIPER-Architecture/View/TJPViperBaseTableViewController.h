//
//  TJPViperBaseTableViewController.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <UIKit/UIKit.h>
#import "TJPViperBaseViewControllerProtocol.h"
#import "TJPBaseTableView.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBasePresenterProtocol;

typedef NS_ENUM(NSInteger, TJPViewControllerState) {
    TJPViewControllerStateIdle,           // 空闲状态
    TJPViewControllerStateInitialLoading, // 初始加载
    TJPViewControllerStateContent,        // 内容显示
    TJPViewControllerStateRefreshing,     // 刷新中
    TJPViewControllerStateLoadingMore,    // 加载更多
    TJPViewControllerStateEmpty,          // 空数据
    TJPViewControllerStateError           // 错误状态
};


@interface TJPViperBaseTableViewController : UIViewController <TJPViperBaseViewControllerProtocol>
// 核心组件
@property (nonatomic, strong) TJPBaseTableView *tableView;
//vc->强引用presenter
@property (nonatomic, strong) id<TJPViperBasePresenterProtocol> basePresenter;

// 状态管理
@property (nonatomic, assign, readonly) TJPViewControllerState currentState;


/// 是否启用下拉刷新
@property (nonatomic, assign) BOOL shouldEnablePullDownRefresh;
/// 是否启用上拉加载更多
@property (nonatomic, assign) BOOL shouldEnablePullUpRefresh;

/// 是否启用缓存
@property (nonatomic, assign) BOOL shouldEnableCache;
@property (nonatomic, assign) BOOL shouldPreventDuplicateRequests;


// 分页信息
@property (nonatomic, assign, readonly) NSInteger currentPage;
@property (nonatomic, assign, readonly) NSInteger totalPage;

// 缓存配置
@property (nonatomic, assign) NSTimeInterval cacheExpiration;


// 子类可重写的方法
- (void)setupTableViewStyle;
- (void)configureInitialState;
- (void)handleStateTransition:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState;
- (void)updateUIForState:(TJPViewControllerState)state withData:(nullable id)data;
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


// 状态控制方法
- (BOOL)transitionToState:(TJPViewControllerState)newState withData:(nullable id)data;
- (void)resetToIdleState;

@end

NS_ASSUME_NONNULL_END
