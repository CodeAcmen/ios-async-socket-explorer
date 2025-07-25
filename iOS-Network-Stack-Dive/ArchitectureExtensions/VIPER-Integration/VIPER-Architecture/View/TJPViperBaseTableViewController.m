//
//  TJPViperBaseTableViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseTableViewController.h"
#import <Masonry/Masonry.h>

#import "TJPViperBasePresenterProtocol.h"
#import "TJPNetworkDefine.h"
#import "TJPToast.h"
#import "TJPViperDefaultErrorHandler.h"


@interface TJPViperBaseTableViewController () <TJPBaseTableViewDelegate>

/// 错误处理器
@property (nonatomic, strong) id<TJPViperErrorHandlerProtocol> errorHandler;

/// 当前页数
@property (nonatomic, assign) NSInteger currentPage;
/// 总页数
@property (nonatomic, assign) NSInteger totalPage;



@end

@implementation TJPViperBaseTableViewController
#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        
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
    
    self.errorHandler = [TJPViperDefaultErrorHandler sharedHandler];
    
    self.currentPage = 1;
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    
    [self initializationUI];
        
    [self triggerInitialDataLoad]; //触发初始化数据
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self configureRefreshControls];
}

//**************************************************


#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
- (void)initializationUI {
    self.view.backgroundColor = [UIColor whiteColor];

    self.tableView = [[TJPBaseTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tjpBaseTableViewDelegate = self;
    [self.view addSubview:self.tableView];

    [self layOutTableView];
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
    //绑定Interactor层跳转信号
    [self.basePresenter bindInteractorToPageSubjectWithView:self];
    //绑定数据更新信号
    [self.basePresenter bindInteractorDataUpdateSubject];
    // throttle防抖动处理
    @weakify(self)
    [[[[[self.basePresenter viewUpdatedDataSignal] takeUntil:self.rac_willDeallocSignal] throttle:0.3] deliverOnMainThread] subscribeNext:^(NSDictionary * _Nullable updateDict) {
        TJPLOG_INFO(@"VIPER 中的VC层------收到Interactor透传过来的数据源更新信号");
        @strongify(self)
        if (updateDict) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self childVCUpdateDatasource:updateDict];
            });
        }
    }];
    
    [self pullDownRefresh];
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

- (void)pullDownRefresh {
    // 重置错误处理状态
    [self.errorHandler resetErrorState];

    self.currentPage = 1;
    [self fetchDataForPageWithCompletion:self.currentPage withCompletion:nil];
}

- (void)pullUpLoadMore {
    if (self.currentPage >= self.totalPage) {
        [self.tableView endRefreshing];
        return;
    }
    self.currentPage++;
    [self fetchDataForPageWithCompletion:self.currentPage withCompletion:nil];
}

- (void)loadDataForPage {
    [self fetchDataForPageWithCompletion:self.currentPage withCompletion:nil];
}


- (void)fetchDataForPageWithCompletion:(NSInteger)page withCompletion:(void (^)(NSArray *messages, NSError *error))completion {
    NSDate *startTime = [NSDate date]; // 记录开始时间
    TJPLOG_INFO(@"Fetching data for page: %ld", (long)page);
    @weakify(self)
    [self.basePresenter fetchInteractorDataForPage:page success:^(NSArray * _Nonnull data,  NSInteger totalPage) {
        @strongify(self)
        TJPLOG_INFO(@"Data fetched successfully for page: %ld, data count: %lu, total pages: %ld", (long)page, (unsigned long)data.count, (long)totalPage);
        
        // 性能追踪
        NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        TJPLOG_INFO(@"Data fetch for page: %ld took %.2f seconds", (long)page, timeElapsed);

        self.totalPage = totalPage;

        [self handleDataFetchSuccess:data error:nil];
    } failure:^(NSError * _Nonnull error) {
        @strongify(self)
        TJPLOG_INFO(@"Failed to fetch data for page: %ld, error: %@", (long)page, error.localizedDescription);
        // 新错误处理机制
        [self handleDataFetchErrorWithRetry:error];
    }];
}

- (void)handleDataFetchErrorWithRetry:(NSError *)error {
    @weakify(self)
    [self.errorHandler handleError:error inContext:self completion:^(BOOL shouldRetry) {
        @strongify(self)
        if (shouldRetry) {
            // 用户选择重试，重新请求数据
            TJPLOG_INFO(@"User chose to retry, fetching data again for page: %ld", (long)self.currentPage);
            [self fetchDataForPageWithCompletion:self.currentPage withCompletion:nil];
        } else {
            // 用户取消重试或达到最大重试次数，显示空白页
            [self handleDataFetchError:error];
        }
    }];
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

- (void)updateTableViewUIForExtensionOperate {
    //交给子类去实现
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
    [self triggerInitialDataLoad];
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
