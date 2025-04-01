//
//  TJPViperBaseTableView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPViperBaseTableView.h"
#import <DZNEmptyDataSet/DZNEmptyDataSet-umbrella.h>

#import "TJPViperBaseCellModelProtocol.h"
#import "TJPViperBaseTableViewCellProtocol.h"

#import "MJRefresh.h"
#import "UIColor+TJPColor.h"
#import "TJPNetworkDefine.h"



#pragma mark -
#pragma mark Constants
#pragma mark -
//**********************************************************************************************************
//
//    Constants
//
//**********************************************************************************************************

#pragma mark -
#pragma mark Private Interface
#pragma mark -
//**********************************************************************************************************
//
//    Private Interface
@interface TJPViperBaseTableView () <UITableViewDelegate, UITableViewDataSource, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

// 使用一个集合来存储已注册的单元格标识符，避免重复注册
@property (nonatomic, strong) NSMutableSet *registeredIdentifiers;



@property (nonatomic, assign) BOOL isShowEmptyData;
// 缓存的 loadingImageView
@property (nonatomic, strong) UIImageView *loadingImageView;


@end
//
//**********************************************************************************************************

#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
@implementation TJPViperBaseTableView

// 初始化方法，设置数据源和代理
- (instancetype)init {
    self = [super init];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        
        self.cellModels = [NSMutableArray array];
        self.registeredIdentifiers = [NSMutableSet set];
        self.emptyDataSetSource = self;
        self.emptyDataSetDelegate = self;
        self.isShowEmptyData = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        
        self.cellModels = [NSMutableArray array];
        self.emptyDataSetSource = self;
        self.emptyDataSetDelegate = self;
        self.isShowEmptyData = NO;
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
    
    // 确保数据源被释放
    self.cellModels = nil;
    // 释放注册的 cell 标识符
    self.registeredIdentifiers = nil;
    [self.loadingImageView.layer removeAllAnimations];
}

//**************************************************
#pragma mark -
#pragma mark ViewLifeCycle
//**************************************************
//    ViewLifeCycle Methods
//**************************************************


//**************************************************
#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
- (void)setCellModels:(NSMutableArray<id<TJPViperBaseCellModelProtocol>> *)cellModels {
    if (_cellModels != cellModels) {
        _cellModels = cellModels;
        
        [self registerCells];
    }
}

- (void)registerCells {
    for (id<TJPViperBaseCellModelProtocol> model in self.cellModels) {
        NSString *cellName = [model cellName];
        Class cellClass = NSClassFromString(cellName);
        NSString *cellIdentifier = NSStringFromClass(cellClass);
        
        //如果该类型已经注册过则跳过注册
        if ([self.registeredIdentifiers containsObject:cellIdentifier]) {
            continue;
        }
        
        [self.registeredIdentifiers addObject:cellIdentifier];
        
        NSBundle *bundle = [NSBundle bundleForClass:cellClass];
        if ([bundle pathForResource:cellIdentifier ofType:@"nib"] != nil) {
            // 如果有 nib 文件，注册 nib
            [self registerNib:[UINib nibWithNibName:cellIdentifier bundle:bundle] forCellReuseIdentifier:cellIdentifier];
            TJPLOG_INFO(@"Registered nib for cell: %@", cellIdentifier);
        } else {
            // 如果没有 nib 文件，注册 class
            [self registerClass:cellClass forCellReuseIdentifier:cellIdentifier];
            TJPLOG_INFO(@"Registered class for cell: %@", cellIdentifier);
        }
    }
}

- (void)configurePullDownRefreshControlWithTarget:(id)target pullDownAction:(SEL)pullDownAction {
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingTarget:target refreshingAction:pullDownAction];
    header.stateLabel.textColor= [UIColor tjp_lightTextColor];
    header.lastUpdatedTimeLabel.hidden = YES;
    self.mj_header = header;
    
    TJPLOG_INFO(@"Configured pull-down refresh control");
}

- (void)configurePullUpRefreshControlWithTarget:(id)target pullUpAction:(SEL)pullUpAction {
    self.mj_footer = [MJRefreshBackNormalFooter footerWithRefreshingTarget:target refreshingAction:pullUpAction];
    TJPLOG_INFO(@"Configured pull-up refresh control");
}

- (void)endRefreshing {
    [self.mj_header endRefreshing];
    [self.mj_footer endRefreshing];
}

//**************************************************


#pragma mark -
#pragma mark Self Public Methods
//**************************************************
//    Self Public Methods

//**************************************************
- (void)reloadDataWithCellModels:(NSArray<id<TJPViperBaseCellModelProtocol>> *)cellModels {
    if ([self.cellModels isEqualToArray:cellModels]) {
        return;
    }

    // 异步进行数据处理
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSIndexPath *> *indexPathsToReload = [NSMutableArray array];
        
        // 判断需要更新的行数
        for (NSInteger i = 0; i < self.cellModels.count; i++) {
            id<TJPViperBaseCellModelProtocol> oldModel = self.cellModels[i];
            id<TJPViperBaseCellModelProtocol> newModel = cellModels[i];
            
            if (![oldModel isEqual:newModel]) {
                [indexPathsToReload addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
        }

        // 根据更新的行数判断是否使用全量更新还是局部更新
        dispatch_async(dispatch_get_main_queue(), ^{
            if (indexPathsToReload.count > 5) {
                TJPLOG_INFO(@"Performing full reload with %lu cell models", (unsigned long)cellModels.count);
                self.cellModels = [cellModels mutableCopy];
                [self reloadData]; // 全量刷新
            } else {
                TJPLOG_INFO(@"Performing partial update with %lu updated rows", (unsigned long)indexPathsToReload.count);
                self.cellModels = [cellModels mutableCopy];
//                [self beginUpdates];
//                [self reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationAutomatic]; // 局部刷新
//                [self endUpdates];
                [self reloadData]; // 全量刷新
            }
        });
    });
}


- (void)showEmptyData {
    self.isShowEmptyData = YES;
    // 刷新空白页显示
    [self reloadEmptyDataSet];
}

- (void)hideEmptyData {
    self.isShowEmptyData = NO;
    // 刷新空白页显示
    [self reloadEmptyDataSet];
}

- (void)tableReloadRowsWithIndexPaths:(NSArray<NSIndexPath *> *)indexPaths animation:(UITableViewRowAnimation)animation {
    if (!indexPaths.count) {
        return;
    }
    [self reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}


//**************************************************


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cellModels.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPViperBaseCellModelProtocol> model = self.cellModels[indexPath.row];
    return model.cellHeight;
}


#pragma mark - UITableViewDelegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPViperBaseCellModelProtocol> model = self.cellModels[indexPath.row];
    NSString *cellIdentifier = [model cellName];  // 获取 cell 的标识符
    
    UITableViewCell<TJPViperBaseTableViewCellProtocol> *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    // 配置 Cell
    [cell configureWithModel:model];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPViperBaseCellModelProtocol> model = self.cellModels[indexPath.row];
    TJPLOG_INFO(@"Row %ld selected with model: %@", (long)indexPath.row, model);
    if (model.selectedCommand) {
        [model.selectedCommand execute:model];
    }
    if (self.tjpViperBaseTableViewDelegate && [self.tjpViperBaseTableViewDelegate respondsToSelector:@selector(tjpTableView:didSelectRowAtIndexPath:)]) {
        [self.tjpViperBaseTableViewDelegate tjpTableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPViperBaseCellModelProtocol> model = self.cellModels[indexPath.row];
    
    UITableViewCell<TJPViperBaseTableViewCellProtocol> *viperCell = (UITableViewCell<TJPViperBaseTableViewCellProtocol> *)cell;
    [viperCell cellWillDisplay:model];
    
    if (self.tjpViperBaseTableViewDelegate && [self.tjpViperBaseTableViewDelegate respondsToSelector:@selector(tjpTableView:willDisplayCell:forRowAtIndexPath:)]) {
        [self.tjpViperBaseTableViewDelegate tjpTableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}


#pragma mark - DZNEmptyDataSetSource && DZNEmptyDataSetDelegate
- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    return [[NSAttributedString alloc] initWithString:@"暂无相关信息" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15], NSForegroundColorAttributeName:[UIColor tjp_lightTextColor]}];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    if (!self.isShowEmptyData) {
        return nil;
    }
    return [UIImage imageNamed:@"image_empty_list"];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return -10;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIColor whiteColor];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapView:(UIView *)view {
    TJPLOG_INFO(@"tap empty data set");
    [self hideEmptyData];
    if (self.tjpViperBaseTableViewDelegate && [self.tjpViperBaseTableViewDelegate respondsToSelector:@selector(tjpEmptyViewDidTapped:)]) {
        [self.tjpViperBaseTableViewDelegate tjpEmptyViewDidTapped:view];
    }
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView {
    TJPLOG_INFO(@"customViewForEmptyDataSet triggered");
    if (self.isShowEmptyData) {
        return nil;
    }
    
    if (!_loadingImageView) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 200)];
        _loadingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 25, 25)];
        _loadingImageView.image = [UIImage imageNamed:@"image_loading_color"];
        _loadingImageView.contentMode = UIViewContentModeScaleAspectFit;
        _loadingImageView.center = CGPointMake(view.center.x, 25);
        
        // 旋转动画
        CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 ];
        rotationAnimation.duration = 2;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = MAXFLOAT;
        
        // 只有在第一次创建时添加动画
        if (_loadingImageView.layer.animationKeys.count == 0) {
            [_loadingImageView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
        }
        
        [view addSubview:_loadingImageView];
        TJPLOG_INFO(@"Custom empty data set view created");
        return view;
    }
    
    return nil;  // 返回已缓存的 loadingImageView
    
}




#pragma mark -
#pragma mark HitTest
//**************************************************
//    HitTest Methods
//**************************************************

#pragma mark -
#pragma mark UserAction
//**************************************************
//    UserAction Methods
//**************************************************

#pragma mark -
#pragma mark Properties Getter & Setter
//**************************************************
//    Properties

//**************************************************

@end
