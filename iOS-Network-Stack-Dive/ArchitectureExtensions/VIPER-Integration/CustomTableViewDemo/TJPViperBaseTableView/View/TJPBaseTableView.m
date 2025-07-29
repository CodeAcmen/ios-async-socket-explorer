//
//  TJPBaseTableView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPBaseTableView.h"
#import <DZNEmptyDataSet/DZNEmptyDataSet-umbrella.h>

#import "TJPBaseCellModelProtocol.h"
#import "TJPBaseTableViewCellProtocol.h"
#import "TJPBaseSectionModelProtocol.h"
#import "TJPBaseTableViewLoadingProtocol.h"
#import "TJPDefaultLoadingAnimation.h"

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
@interface TJPBaseTableView () <UITableViewDelegate, UITableViewDataSource, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>
// section数据
@property (nonatomic, strong) NSArray<id<TJPBaseSectionModelProtocol>> *internalSections;

// 使用一个集合来存储已注册的单元格标识符，避免重复注册
@property (nonatomic, strong) NSMutableSet *registeredIdentifiers;


// 是否显示空视图标记
@property (nonatomic, assign) BOOL isShowEmptyData;


@end
//
//**********************************************************************************************************

#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
@implementation TJPBaseTableView

// 初始化方法，设置数据源和代理
- (void)commonInit {
    self.delegate = self;
    self.dataSource = self;
    self.cellModels = [NSMutableArray array];
    self.internalSections = [NSMutableArray array];
    self.registeredIdentifiers = [NSMutableSet set];
    self.emptyDataSetSource = self;
    self.emptyDataSetDelegate = self;
    self.loadingAnimation = [[TJPDefaultLoadingAnimation alloc] init];
    self.isShowEmptyData = NO;
}

- (instancetype)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    if (self = [super initWithFrame:frame style:style]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
    
    // 确保数据源被释放
    self.cellModels = nil;
    self.internalSections = nil;
    // 释放注册的 cell 标识符
    self.registeredIdentifiers = nil;
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
- (void)setCellModels:(NSMutableArray<id<TJPBaseCellModelProtocol>> *)cellModels {
    if (_cellModels != cellModels) {
        _cellModels = cellModels;
        
        [self registerCells];
    }
}

- (void)setSectionModels:(NSArray<id<TJPBaseSectionModelProtocol>> *)sectionModels {
    if (_internalSections != sectionModels) {
        _internalSections = sectionModels;
        [self registerCellsForSections:sectionModels];
    }
}

- (void)registerCells {
    for (id<TJPBaseCellModelProtocol> model in self.cellModels) {
        NSString *cellName = [model cellName];
        Class cellClass = NSClassFromString(cellName);
        NSString *cellIdentifier = NSStringFromClass(cellClass);
        
        //如果该类型已经注册过则跳过注册
        if ([self.registeredIdentifiers containsObject:cellIdentifier]) {
            continue;
        }
        
        
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
        [self.registeredIdentifiers addObject:cellIdentifier];
    }
}

- (void)registerCellsForSections:(NSArray<id<TJPBaseSectionModelProtocol>> *)sections {
    for (id<TJPBaseSectionModelProtocol> section in sections) {
        for (id<TJPBaseCellModelProtocol> model in section.cellModels) {
            NSString *cellName = [model cellName];
            Class cellClass = NSClassFromString(cellName);
            NSString *cellIdentifier = NSStringFromClass(cellClass);
            
            //如果该类型已经注册过则跳过注册
            if ([self.registeredIdentifiers containsObject:cellIdentifier]) {
                continue;
            }

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
            [self.registeredIdentifiers addObject:cellIdentifier];
        }
    }
}

//**************************************************


#pragma mark -
#pragma mark Self Public Methods
//**************************************************
//    Self Public Methods

//**************************************************
- (void)reloadDataWithSectionModels:(NSArray<id<TJPBaseSectionModelProtocol>> *)sections {
    if (sections == nil || sections.count == 0) {
        TJPLOG_WARN(@"[TJPBaseTableView] sectionModels 为空，请检查!!当前sectionModels已赋值为@[]");
        sections = @[];
    }
    self.internalSections = sections;

    if (sections.count == 1 && [sections.firstObject conformsToProtocol:@protocol(TJPBaseSectionModelProtocol)]) {
        id<TJPBaseSectionModelProtocol> section = sections.firstObject;
        // 如果是单 Section 且符合协议，复用已有 Diff 刷新逻辑
        [self reloadDataWithCellModels:section.cellModels];
        return;
    }

    // 多 section 情况：暂时使用全量刷新（未来可支持 diff）
    TJPLOG_INFO(@"[TJPBaseTableView] 全量刷新，section 数量: %lu", (unsigned long)sections.count);
    [self reloadData];
}


- (void)reloadDataWithCellModels:(NSArray<id<TJPBaseCellModelProtocol>> *)cellModels {
    if ([self.cellModels isEqualToArray:cellModels]) {
        return;
    }
    
    // 此处使用拷贝快照防止线程问题
    NSArray *oldModels = [self.cellModels copy];  // 拷贝为不可变数组，线程安全

    // 异步进行数据处理
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSIndexPath *> *indexPathsToReload = [NSMutableArray array];
        
        // 判断需要更新的行数
        for (NSInteger i = 0; i < MIN(oldModels.count, cellModels.count); i++) {
            id<TJPBaseCellModelProtocol> oldModel = oldModels[i];
            id<TJPBaseCellModelProtocol> newModel = cellModels[i];
            
            if (![oldModel isEqual:newModel]) {
                [indexPathsToReload addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
        }

        // 根据更新的行数判断是否使用全量更新还是局部更新
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cellModels = [cellModels mutableCopy];
            // 如果是第一次加载数据或没有有效的 indexPathsToReload，进行全量刷新
                if (indexPathsToReload.count > 5 || indexPathsToReload.count == 0) {
                    TJPLOG_INFO(@"执行全量刷新，cell 数量: %lu", (unsigned long)cellModels.count);
                    [self reloadData]; // 全量刷新
                } else {
                    // 如果是局部刷新，确保 indexPathsToReload 是有效的
                    TJPLOG_INFO(@"执行局部更新，更新的行数: %lu", (unsigned long)indexPathsToReload.count);
                    [self beginUpdates];
                    [self reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationAutomatic]; // 局部刷新
                    [self endUpdates];
                }
        });
    });
}

- (void)reloadSection:(NSInteger)section withAnimation:(UITableViewRowAnimation)animation {
    if (section < self.internalSections.count) {
        [self reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:animation];
    }
}

- (void)tableReloadRowsWithIndexPaths:(NSArray<NSIndexPath *> *)indexPaths animation:(UITableViewRowAnimation)animation {
    if (!indexPaths.count) {
        return;
    }
    [self reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
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

- (void)configurePullDownRefreshControlWithTarget:(id)target pullDownAction:(SEL)pullDownAction {
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingTarget:target refreshingAction:pullDownAction];
    header.stateLabel.textColor= [UIColor tjp_lightTextColor];
    header.lastUpdatedTimeLabel.hidden = YES;
    self.mj_header = header;
    
    TJPLOG_INFO(@"配置下拉刷新控件");
}

- (void)configurePullUpRefreshControlWithTarget:(id)target pullUpAction:(SEL)pullUpAction {
    self.mj_footer = [MJRefreshBackNormalFooter footerWithRefreshingTarget:target refreshingAction:pullUpAction];
    TJPLOG_INFO(@"配置上拉加载更多控件");
}

- (void)endRefreshing {
    [self.mj_header endRefreshing];
    [self.mj_footer endRefreshing];
}

- (void)noMoreData {
    [self.mj_footer endRefreshingWithNoMoreData];
}

//**************************************************


#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.internalSections.count > 0 ? self.internalSections.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < self.internalSections.count) {
        id<TJPBaseSectionModelProtocol> sectionModel = self.internalSections[section];
        return sectionModel.cellModels.count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPBaseSectionModelProtocol> section = self.internalSections[indexPath.section];
    id<TJPBaseCellModelProtocol> model = section.cellModels[indexPath.row];
    return model.cellHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < self.internalSections.count) {
        id<TJPBaseSectionModelProtocol> sectionModel = self.internalSections[section];
        return [sectionModel respondsToSelector:@selector(sectionTitle)] ? sectionModel.sectionTitle : @"";
    }
    return @"";
    
}

#pragma mark - UITableViewDelegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= self.internalSections.count) {
        TJPLOG_WARN(@"[TJPBaseTableView] section越界: %ld", indexPath.section);
        return [self defaultErrorCell:@"section 越界"];
    }
    
    id<TJPBaseSectionModelProtocol> sectionModel = self.internalSections[indexPath.section];
    if (indexPath.row >= sectionModel.cellModels.count) {
        TJPLOG_WARN(@"[TJPBaseTableView] row越界: %ld", indexPath.row);
        return [self defaultErrorCell:@"row 越界"];
    }
    
    
    id<TJPBaseCellModelProtocol> model = sectionModel.cellModels[indexPath.row];
    NSString *cellIdentifier = [model cellName];
    
    UITableViewCell<TJPBaseTableViewCellProtocol> *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        TJPLOG_WARN(@"[TJPBaseTableView] 找不到注册的cell: %@", cellIdentifier);
        return [self defaultErrorCell:@"未注册cell"];
    }
    
    if ([cell respondsToSelector:@selector(configureWithModel:)]) {
        [(id)cell configureWithModel:model];
    }
    
    return cell;
}

- (UITableViewCell *)defaultErrorCell:(NSString *)msg {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = [NSString stringWithFormat:@"⚠️ %@", msg];
    cell.textLabel.textColor = [UIColor redColor];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPBaseSectionModelProtocol> section = self.internalSections[indexPath.section];
    id<TJPBaseCellModelProtocol> model = section.cellModels[indexPath.row];
    
    TJPLOG_INFO(@"第 %ld 行被选中，模型: %@", (long)indexPath.row, model);
    if (model.selectedCommand) {
        [model.selectedCommand execute:model];
    }
    if (self.tjpBaseTableViewDelegate && [self.tjpBaseTableViewDelegate respondsToSelector:@selector(tjpTableView:didSelectRowAtIndexPath:)]) {
        [self.tjpBaseTableViewDelegate tjpTableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    id<TJPBaseSectionModelProtocol> section = self.internalSections[indexPath.section];
    id<TJPBaseCellModelProtocol> model = section.cellModels[indexPath.row];

    UITableViewCell<TJPBaseTableViewCellProtocol> *viperCell = (UITableViewCell<TJPBaseTableViewCellProtocol> *)cell;
    [viperCell cellWillDisplay:model];
    
    if (self.tjpBaseTableViewDelegate && [self.tjpBaseTableViewDelegate respondsToSelector:@selector(tjpTableView:willDisplayCell:forRowAtIndexPath:)]) {
        [self.tjpBaseTableViewDelegate tjpTableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}


#pragma mark - DZNEmptyDataSetSource && DZNEmptyDataSetDelegate
- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    return [[NSAttributedString alloc] initWithString:@"暂无相关数据" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15], NSForegroundColorAttributeName:[UIColor tjp_lightTextColor]}];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    if (!self.isShowEmptyData) {
        return nil;
    }
    return [UIImage imageNamed:@"img_data_empty"];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return -40;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIColor whiteColor];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapView:(UIView *)view {
    TJPLOG_INFO(@"点击了空数据视图");
    [self hideEmptyData];
    if (self.tjpBaseTableViewDelegate && [self.tjpBaseTableViewDelegate respondsToSelector:@selector(tjpEmptyViewDidTapped:)]) {
        [self.tjpBaseTableViewDelegate tjpEmptyViewDidTapped:view];
    }
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView {
    if (self.isShowEmptyData) {
        return nil;
    }
    return [self.loadingAnimation customLoadingView];
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
