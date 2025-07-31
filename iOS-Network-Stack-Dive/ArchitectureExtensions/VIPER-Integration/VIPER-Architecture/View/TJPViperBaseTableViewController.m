//
//  TJPViperBaseTableViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseTableViewController.h"
#import <Masonry/Masonry.h>

#import "TJPToast.h"
#import "TJPViewControllerStateMachine.h"
#import "TJPViperBasePresenterProtocol.h"
#import "TJPNetworkDefine.h"
#import "TJPViperDefaultErrorHandler.h"

@interface TJPViperBaseTableViewController () <TJPBaseTableViewDelegate, TJPViewControllerStateMachineDelegate>

// 状态管理
@property (nonatomic, strong) TJPViewControllerStateMachine *stateMachine;

// 错误处理器
@property (nonatomic, strong) id<TJPViperErrorHandlerProtocol> errorHandler;


// 数据管理
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger totalPage;
@property (nonatomic, strong) NSMutableArray *dataArray;
@property (nonatomic, assign) NSInteger requestingPage;

// 请求管理
@property (nonatomic, strong) NSMutableSet<NSNumber *> *activeRequests;

// 生命周期标记
@property (nonatomic, assign) BOOL hasAppeared;
@property (nonatomic, assign) BOOL isInitialized;

@end

@implementation TJPViperBaseTableViewController
#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
}

//**************************************************


#pragma mark -
#pragma mark ViewLifeCycle
//**************************************************
//    ViewLifeCycle Methods
//**************************************************
- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    
    // 配置初始状态
    [self configureInitialState];
    // 初始化UI
    [self initializationUI];
    // 初始化数据
    [self triggerInitialDataLoad];
    
    self.isInitialized = YES;
    
    TJPLOG_INFO(@"[TJPViperBaseTableViewController] viewDidLoad 方法执行完成");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self configureRefreshControls];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // 取消当前页面的所有请求
    [self.activeRequests removeAllObjects];
}

//**************************************************


#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
- (void)commonInit {
    // 初始化状态机
    _stateMachine = [[TJPViewControllerStateMachine alloc] initWithInitialState:TJPViewControllerStateIdle];
    _stateMachine.delegate = self;

    // 初始化为0，表示还没有加载任何页面
    _currentPage = 0;
    _totalPage = 1;
    _requestingPage = 0;
    _dataArray = [NSMutableArray array];
    _activeRequests = [NSMutableSet set];
    
    // 默认配置
    _shouldEnablePullDownRefresh = YES;
    _shouldEnablePullUpRefresh = YES;
    _shouldPreventDuplicateRequests = YES;
    
    // 初始化错误处理
    _errorHandler = [TJPViperDefaultErrorHandler sharedHandler];
//    _errorHandler.delegate = self;
}

- (void)configureInitialState {
    self.view.backgroundColor = [UIColor whiteColor];
    // 子类可重写此方法进行特定配置
}

- (void)initializationUI {
    self.tableView = [[TJPBaseTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tjpBaseTableViewDelegate = self;
    [self.view addSubview:self.tableView];

    [self setupTableViewStyle];

    [self layOutTableView];
}

- (void)setupTableViewStyle {
    // 子类可重写此方法自定义TableView样式
}

- (void)layOutTableView {
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom).offset(insets.top);
        make.bottom.equalTo(self.view).offset(insets.bottom);
    }];
}

- (void)triggerInitialDataLoad {
    if (!self.basePresenter) {
        TJPLOG_ERROR(@"basePresenter 为空,无法加载数据!请检查!");
        return;
    }
    
    // 绑定Interactor透传的跳转信号
    [self bindInteractorSignals];
    // 下拉刷新
    [self pullDownRefresh];
    // 请求第一页数据
    [self loadDataForPage:1];

}

- (void)bindInteractorSignals {
    [self.basePresenter bindInteractorToPageSubjectWithContextProvider:self];
    // 绑定数据更新信号
    [self.basePresenter bindInteractorDataUpdateSubject];
    // throttle防抖动处理
    @weakify(self)
    [[[[[self.basePresenter viewUpdatedDataSignal] takeUntil:self.rac_willDeallocSignal] throttle:0.3] deliverOnMainThread] subscribeNext:^(NSDictionary * _Nullable updateDict) {
        TJPLOG_INFO(@"[TJPViperBaseTableViewController] VC层收到Interactor透传过来的数据源更新信号");
        @strongify(self)
        if (updateDict && self.isInitialized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self childVCUpdateDatasource:updateDict];
            });
        }
    }];
}

#pragma mark - TJPViperBaseViewControllerProtocol
- (UIViewController *)currentViewController {
    return self;
}

#pragma mark - State Management
- (TJPViewControllerState)currentState {
    return self.stateMachine.currentState;
}

- (BOOL)transitionToState:(TJPViewControllerState)newState {
    return [self.stateMachine transitionToState:newState];
}

- (void)resetToIdleState {
    [self.stateMachine resetToIdleState];
}


#pragma mark - TJPViewControllerStateMachineDelegate

- (void)stateMachine:(TJPViewControllerStateMachine *)stateMachine didTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState {
    // 处理状态转换逻辑
    [self handleStateTransition:fromState toState:toState];
    
    // 更新UI
    [self updateUIForState:toState withData:self.dataArray];
}

- (BOOL)stateMachine:(TJPViewControllerStateMachine *)stateMachine shouldTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState {
    // 可以在这里添加状态转换的前置条件检查
    return YES;
}

- (void)stateMachine:(TJPViewControllerStateMachine *)stateMachine failedTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState {
    TJPLOG_WARN(@"状态转换失败: %@ -> %@", [stateMachine stateDescription:fromState], [stateMachine stateDescription:toState]);
}

- (void)handleStateTransition:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState {
    // 子类可重写此方法处理特定的状态转换逻辑
}

- (void)updateUIForState:(TJPViewControllerState)state withData:(nullable id)data {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (state) {
            case TJPViewControllerStateInitialLoading:
                [self showInitialLoadingState];
                break;
                
            case TJPViewControllerStateContent:
                [self showContentState:data];
                break;
                
            case TJPViewControllerStateRefreshing:
                // 刷新状态下不需要额外UI更新，刷新控件会自动显示
                break;
                
            case TJPViewControllerStateLoadingMore:
                // 加载更多状态下不需要额外UI更新
                break;
                
            case TJPViewControllerStateEmpty:
                [self showEmptyState];
                break;
                
            case TJPViewControllerStateError:
                [self showErrorState:data];
                break;
                
            default:
                break;
        }
    });
}
#pragma mark - Data Management
- (void)reloadData {
    [self resetToIdleState];
    [self loadDataForPage:1];
}

- (void)loadDataForPage:(NSInteger)page {
    // 检查是否应该阻止重复请求
    NSNumber *pageKey = @(page);
    if (self.shouldPreventDuplicateRequests && [self.activeRequests containsObject:pageKey]) {
        TJPLOG_INFO(@"第 %ld 页的请求已经在进行中", (long)page);
        return;
    }
        
    // 更新状态
    if (page == 1) {
        if (self.currentState == TJPViewControllerStateContent) {
            [self.stateMachine transitionToState:TJPViewControllerStateRefreshing];
        } else {
            [self.stateMachine transitionToState:TJPViewControllerStateInitialLoading];
        }
    } else {
        [self.stateMachine transitionToState:TJPViewControllerStateLoadingMore];
    }
    
    // 标记请求开始
    [self.activeRequests addObject:pageKey];
    
    // 执行数据请求
    [self fetchDataForPage:page];
}

- (void)refreshData {
    [self loadDataForPage:1];
}

- (void)loadMoreData {
    if (self.currentPage >= self.totalPage) {
        [self.tableView endRefreshing];
        [self.tableView noMoreData];
        return;
    }
    
    [self loadDataForPage:self.currentPage + 1];
}

- (void)fetchDataForPage:(NSInteger)page {
    // 记录当前请求的页码
    self.requestingPage = page;
    NSDate *startTime = [NSDate date];
    NSNumber *pageKey = @(page);
    
    TJPLOG_INFO(@"正在请求第 %ld 页的数据", (long)page);

    @weakify(self)
    [self.basePresenter fetchInteractorDataForPage:page success:^(NSArray *data, NSInteger totalPage) {
        @strongify(self)
        
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
        TJPLOG_INFO(@"第 %ld 页数据请求成功（%.2fs）", (long)page, duration);

        // 移除请求标记
        [self.activeRequests removeObject:pageKey];
                
        // 传递请求的页码
        [self handleDataFetchSuccess:data totalPage:totalPage forPage:page];

    } failure:^(NSError *error) {
        @strongify(self)
        
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
        TJPLOG_ERROR(@"第 %ld 页数据请求失败（%.2fs）: %@", (long)page, duration, error.localizedDescription);

        // 移除请求标记
        [self.activeRequests removeObject:pageKey];
        
        [self handleDataFetchError:error forPage:page];
    }];
}
- (void)handleDataFetchSuccess:(NSArray *)data totalPage:(NSInteger)totalPage forPage:(NSInteger)requestPage {
    // 重置数据的条件：第一页或刷新状态
    if (requestPage == 1 || self.currentState == TJPViewControllerStateRefreshing) {
        // 第一页或刷新，替换数据源
        [self.dataArray removeAllObjects];
        self.currentPage = 0;  // 重置为0
        TJPLOG_DEBUG(@"[TJPViperBaseTableViewController] 重置数据，currentPage设置为0");
    }
    
    if (data.count > 0) {
        [self.dataArray addObjectsFromArray:data];
        self.currentPage = requestPage;
        TJPLOG_DEBUG(@"[TJPViperBaseTableViewController] 数据添加完成，currentPage更新为: %ld", (long)self.currentPage);
    }
    
    self.totalPage = totalPage;
    
    // 更新状态
    if (self.dataArray.count == 0) {
        [self.stateMachine transitionToState:TJPViewControllerStateEmpty];
    } else {
        [self.stateMachine transitionToState:TJPViewControllerStateContent];
    }
    
    // 结束刷新
    [self.tableView endRefreshing];
}

- (void)handleDataFetchSuccess:(NSArray *)data totalPage:(NSInteger)totalPage {
    [self handleDataFetchSuccess:data totalPage:totalPage forPage:self.requestingPage];
}

- (void)handleDataFetchError:(NSError *)error forPage:(NSInteger)page {
    @weakify(self)
    [self.errorHandler handleError:error inContext:self completion:^(BOOL shouldRetry) {
        @strongify(self)
        if (shouldRetry) {
            [self fetchDataForPage:page];
        } else {
            // 更新状态为错误
            [self.stateMachine transitionToState:TJPViewControllerStateError];
            [self.tableView endRefreshing];
        }
    }];
}

#pragma mark - UI State Methods
- (void)showInitialLoadingState {
    
}

- (void)showContentState:(NSArray *)data {
    [self.tableView hideEmptyData];
    [self.tableView reloadDataWithSectionModels:data];
}

- (void)showEmptyState {
    [self.tableView showEmptyData];
}

- (void)showErrorState:(NSError *)error {
    // 显示错误专用的空状态页
    [self.tableView showEmptyData];
}


//**************************************************
- (void)configureRefreshControls {
    // 配置下拉刷新
    if (self.shouldEnablePullDownRefresh) {
        [self.tableView configurePullDownRefreshControlWithTarget:self pullDownAction:@selector(pullDownRefresh)];
    }
    
    // 配置上拉加载更多
    if (self.shouldEnablePullUpRefresh) {
        [self.tableView configurePullUpRefreshControlWithTarget:self pullUpAction:@selector(pullUpLoadMore)];
    }
}


#pragma mark - Pull to Refresh

- (void)pullDownRefresh {
    [self refreshData];
}

- (void)pullUpLoadMore {
    [self loadMoreData];
}

#pragma mark - Helper Methods

- (NSString *)cacheKeyForPage:(NSInteger)page {
    return [NSString stringWithFormat:@"%@_page_%ld", NSStringFromClass([self class]), (long)page];
}

- (NSString *)requestKeyForPage:(NSInteger)page {
    return [NSString stringWithFormat:@"%@_request_%ld", NSStringFromClass([self class]), (long)page];
}

- (void)updateTableViewUIForExtensionOperate {
    //交给子类去实现
}

- (void)handleDataUpdate:(NSDictionary *)updateDict {
    // 子类可重写此方法处理特定的数据更新逻辑
    TJPLOG_INFO(@"接收到数据更新: %@", updateDict);
}

- (void)handleDataFetchSuccess:(NSArray *)data error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateEmptyDataViewForSectionModels:data error:nil];
        [self.tableView endRefreshing];
    });
}

- (void)handleDataFetchError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *errorMessage = [self getErrorMessageForError:error];

        [self showError:errorMessage];
        [self updateEmptyDataViewForSectionModels:nil error:error];
        [self.tableView endRefreshing];
    });
}

- (void)updateEmptyDataViewForSectionModels:(NSArray *)sections error:(NSError *)error {
    if (error || sections.count == 0) {
        [self.tableView showEmptyData];
    } else {
        [self.tableView hideEmptyData];
        [self.tableView reloadDataWithSectionModels:sections];
    }
    //对tableView进行额外扩展操作
    [self updateTableViewUIForExtensionOperate];
}

- (NSString *)getErrorMessageForError:(NSError *)error {
    if (error.code == NSURLErrorNotConnectedToInternet) {
        return @"网络连接失败，请检查您的网络设置";
    } else if (error.code == NSURLErrorTimedOut) {
        return @"请求超时，请稍后再试";
    } else {
        return error.localizedDescription ?: @"加载失败，请重试";
    }
}


#pragma mark -
#pragma mark Self Public Methods
//**************************************************
//    Self Public Methods
- (void)showError:(nonnull NSString *)error {
    [TJPToast show:error duration:1.0];
    
}


- (void)tjpEmptyViewDidTapped:(UIView *)view {
    [self reloadData];
}



//**************************************************


#pragma mark -
#pragma mark Override Public Methods
//**************************************************
//    Override Public Methods


//**************************************************


#pragma mark -
#pragma mark Override Private Methods
//**************************************************
//    Override Public Methods

- (void)childVCUpdateDatasource:(NSDictionary *)updateDict {
    //交给子类去重写
}


//**************************************************


#pragma mark -
#pragma mark Properties Getter & Setter
//**************************************************
//    Properties

//**************************************************



@end
