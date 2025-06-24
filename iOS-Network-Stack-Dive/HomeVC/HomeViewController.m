//
//  HomeViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import "HomeViewController.h"
#import "TJPViperModuleProvider.h"

#import "StickPacketDemoController.h"
#import "StickPacketSolutionController.h"
#import "TJPLoggerViewController.h"
#import "TJPCustomTableViewDemoViewController.h"
#import "TJPVIPERDemoViewController.h"
#import "TJPNetworkMonitorViewController.h"
#import "TJPChatViewController.h"




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
                @{ @"title": @"粘包问题解决方案", @"viewController": [StickPacketSolutionController class] },
                @{ @"title": @"TCP通信框架监控演示", @"viewController": [TJPNetworkMonitorViewController class] }
            ]
        },
        @{
            @"title": @"AOP实现",
            @"viewControllers": @[
                @{ @"title": @"轻量级切面日志", @"viewController": [TJPLoggerViewController class] },
            ]
        },
        @{
            @"title": @"UI实现",
            @"viewControllers": @[
                @{ @"title": @"封装VIPER-TableView演示", @"viewController": [TJPCustomTableViewDemoViewController class] },
                @{ @"title": @"VIPER架构演示", @"viewController": @"VIPERDemo" },
//                @{ @"title": @"聊天界面实战", @"viewController": [TJPChatViewController class] }
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
    id vcEntry = vcInfo[@"viewController"];

    UIViewController *vc = nil;
    if ([vcEntry isKindOfClass:[NSString class]]) {
        if ([vcEntry isEqualToString:@"VIPERDemo"]) {
            vc = [self.tjpViperModuleProvider viperDemoViewController];
        }
    } else {
        // 是 class，需要 alloc init
        vc = [[(Class)vcEntry alloc] init];
    }

    if (vc) {
        [self.navigationController pushViewController:vc animated:YES];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
