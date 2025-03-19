//
//  HomeViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import "HomeViewController.h"
#import "StickPacketDemoController.h"
#import "StickPacketSolutionController.h"


@interface HomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *sectionsData;


@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = @"iOS-Network";
    
    [self initData];
    
    [self setupTableView];
}

- (void)initData {
    self.sectionsData = @[
        @{
            @"title": @"Socket实践",
            @"viewControllers": @[
                @{ @"title": @"粘包问题演示", @"viewController": [StickPacketDemoController class] },
                @{ @"title": @"粘包问题解决方案", @"viewController": [StickPacketSolutionController class] }
            ]
        },
        @{
            @"title": @"粘包问题解决方案",
            @"viewControllers": @[
                @{ @"title": @"方案1", @"viewController": [StickPacketDemoController class] },
                @{ @"title": @"方案2", @"viewController": [StickPacketSolutionController class] },
                @{ @"title": @"方案3", @"viewController": [StickPacketDemoController class] }
            ]
        }
    ];
}


- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionsData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *viewControllers = self.sectionsData[section][@"viewControllers"];
    return viewControllers.count;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionsData[section][@"title"];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSArray *viewControllers = self.sectionsData[indexPath.section][@"viewControllers"];
    NSDictionary *vcInfo = viewControllers[indexPath.row];
    
    cell.textLabel.text = vcInfo[@"title"];
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *viewControllers = self.sectionsData[indexPath.section][@"viewControllers"];
    NSDictionary *vcInfo = viewControllers[indexPath.row];
    Class selectedVCClass = vcInfo[@"viewController"];
    
    UIViewController *vc = [[selectedVCClass alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
