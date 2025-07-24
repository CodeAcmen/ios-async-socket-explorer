//
//  TJPSectionTableViewDemoViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//

#import "TJPSectionTableViewDemoViewController.h"
#import <Masonry/Masonry.h>

#import "TJPBaseTableView.h"
#import "TJPBaseSectionModel.h"
#import "TJPBaseCellModel.h"
#import "TJPBaseTableViewCell.h"


@interface TJPSectionDemoCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;


@end

@implementation TJPSectionDemoCellModel

- (NSString *)cellName {
    return @"TJPSectionDemoTableViewCell";
}


@end

@interface TJPSectionDemoTableViewCell : TJPBaseTableViewCell

@property (nonnull, strong) UILabel *titleLabel;
@property (nonatomic, weak) TJPSectionDemoCellModel *cellModel;

@end

@implementation TJPSectionDemoTableViewCell
@synthesize cellModel = _cellModel;

- (void)initializationChildUI {
    self.titleLabel = [UILabel new];
    [self.contentView addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(self.contentView);
        make.left.mas_equalTo(15);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    self.titleLabel.text = self.cellModel.title;
}


@end

@interface TJPSectionTableViewDemoViewController () <TJPBaseTableViewDelegate>
@property (nonatomic, strong) TJPBaseTableView *tableView;
@property (nonatomic, strong) NSArray *sectionedData;

@property (nonatomic, strong) RACCommand<TJPSectionDemoCellModel *, NSObject *> *selectCommand;



@end

@implementation TJPSectionTableViewDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.title = @"VIPER 多Section列表";

    self.sectionedData = @[
        @{
            @"title": @"常规内容",
            @"items": @[
                @{@"title": @"常规-1", @"subtitle": @"描述-A"},
                @{@"title": @"常规-2", @"subtitle": @"描述-B"}
            ]
        },
        @{
            @"title": @"推荐内容",
            @"items": @[
                @{@"title": @"推荐-1", @"subtitle": @"推荐内容-A"},
                @{@"title": @"推荐-2", @"subtitle": @"推荐内容-B"},
                @{@"title": @"推荐-3", @"subtitle": @"推荐内容-C"}
            ]
        }
    ];

    self.tableView = [[TJPBaseTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.tjpBaseTableViewDelegate = self;
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    self.tableView.sectionModels = [self buildSectionModels];
}

- (NSArray<id<TJPBaseSectionModelProtocol>> *)buildSectionModels {
    NSMutableArray *sections = [NSMutableArray array];
    
    for (NSDictionary *sectionDict in self.sectionedData) {
        NSMutableArray *cellModels = [NSMutableArray array];
        for (NSDictionary *item in sectionDict[@"items"]) {
            TJPSectionDemoCellModel *model = [[TJPSectionDemoCellModel alloc] init];
            model.title = item[@"title"];
            model.subTitle = item[@"subtitle"];
            [cellModels addObject:model];
        }
        
        TJPBaseSectionModel *sectionModel = [[TJPBaseSectionModel alloc] initWithCellModels:cellModels];
        sectionModel.sectionTitle = sectionDict[@"title"];
        sectionModel.sectionHeaderHeight = 40.0;
        [sections addObject:sectionModel];
    }
    
    return sections;
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



- (RACCommand<TJPSectionDemoCellModel *,NSObject *> *)selectCommand {
    if (nil == _selectCommand) {
        _selectCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPSectionDemoCellModel * _Nullable input) {
            NSLog(@"当前点击了cell  subtitle: %@", input.subTitle);
            return [RACSignal empty];
        }];
    }
    return _selectCommand;
}


@end
