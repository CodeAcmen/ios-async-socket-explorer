//
//  TJPViperBaseTableViewController.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <UIKit/UIKit.h>
#import "TJPViperBaseTableVCProtocol.h"
#import "TJPViperBaseTableView.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBasePresenterProtocol;


@interface TJPViperBaseTableViewController : UIViewController <TJPViperBaseTableVCProtocol>
@property (nonatomic, strong) TJPViperBaseTableView *tableView;


//vc->强引用presenter
@property (nonatomic, strong) id<TJPViperBasePresenterProtocol> basePresenter;


/// 是否启用下拉刷新
@property (nonatomic, assign) BOOL shouldEnablePullDownRefresh;
/// 是否启用上拉加载更多
@property (nonatomic, assign) BOOL shouldEnablePullUpRefresh;


/// 额外操作TableViewUI方法
- (void)updateTableViewUIForExtensionOperate;

/// 配置刷新控件
- (void)configureRefreshControls;
/// 获取数据
- (void)loadDataForPage;

@end

NS_ASSUME_NONNULL_END
