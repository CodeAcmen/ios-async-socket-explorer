//
//  TJPCustomTableViewDemoViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPCustomTableViewDemoViewController.h"
#import <Masonry/Masonry.h>

#import "TJPViperBaseTableView.h"
#import "TJPViperBaseCellModel.h"
#import "TJPViperBaseTableViewCell.h"

@interface TJPViperDemoCellModel : TJPViperBaseCellModel

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;


@end

@implementation TJPViperDemoCellModel

- (NSString *)cellName {
    return @"TJPViperDemoTableViewCell";
}


@end

@interface TJPViperDemoTableViewCell : TJPViperBaseTableViewCell

@property (nonnull, strong) UILabel *titleLabel;
@property (nonatomic, weak) TJPViperDemoCellModel *cellModel;

@end

@implementation TJPViperDemoTableViewCell
@synthesize cellModel = _cellModel;

- (void)initializationChildUI {
    self.titleLabel = [UILabel new];
    [self.contentView addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(self.contentView);
        make.left.mas_equalTo(15);
    }];
}

- (void)configureWithModel:(id<TJPViperBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    self.titleLabel.text = self.cellModel.title;
}


@end


@interface TJPCustomTableViewDemoViewController () <TJPViperBaseTableViewDelegate>
@property (nonatomic, strong) TJPViperBaseTableView *tableView;
@property (nonatomic, strong) NSArray *demoData; 

@property (nonatomic, strong) RACCommand<TJPViperDemoCellModel *, NSObject *> *selectCommand;


@end

@implementation TJPCustomTableViewDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"VIPER-TableView Demo";

    self.demoData = @[
        @{@"title": @"Item 1", @"subtitle": @"Description 1"},
        @{@"title": @"Item 2", @"subtitle": @"Description 2"},
        @{@"title": @"Item 3", @"subtitle": @"Description 3"},
        @{@"title": @"Item 4", @"subtitle": @"Description 4"},
        @{@"title": @"Item 5", @"subtitle": @"Description 5"}
    ];
    
    self.tableView = [[TJPViperBaseTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.tjpViperBaseTableViewDelegate = self;
    self.tableView.cellModels = [[self createCellModelsFromData:self.demoData] mutableCopy];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom);
        make.bottom.equalTo(self.view);
    }];
    
    [self.tableView configurePullDownRefreshControlWithTarget:self pullDownAction:@selector(handlePullDownRefresh)];
    [self.tableView configurePullUpRefreshControlWithTarget:self pullUpAction:@selector(handlePullUpRefresh)];
}

// 将 demoData 转换为 cell 模型数组
- (NSArray *)createCellModelsFromData:(NSArray *)data {
    NSMutableArray *models = [NSMutableArray array];
    
    for (NSDictionary *item in data) {
        TJPViperDemoCellModel *model = [[TJPViperDemoCellModel alloc] init];
        model.title = item[@"title"];
        model.subTitle = item[@"subtitle"];
        model.selectedCommand = self.selectCommand;
//        model.cellHeight = 60;
        [models addObject:model];
    }
    
    return models;
}

// 下拉刷新处理方法
- (void)handlePullDownRefresh {
    // 模拟刷新操作
    NSLog(@"Pull down to refresh...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView endRefreshing];
    });
}

// 上拉加载更多处理方法
- (void)handlePullUpRefresh {
    // 模拟加载更多操作
    NSLog(@"Pull up to load more...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView endRefreshing];
    });
}


- (RACCommand<TJPViperDemoCellModel *,NSObject *> *)selectCommand {
    if (nil == _selectCommand) {
        _selectCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPViperDemoCellModel * _Nullable input) {
            NSLog(@"当前点击了cell  subtitle: %@", input.subTitle);
            return [RACSignal empty];
        }];
    }
    return _selectCommand;
}


@end
