//
//  TJPNetworkMonitorViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/14.
//

#import "TJPNetworkMonitorViewController.h"
#import "TJPNetworkConfig.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkCoordinator.h"

#import "TJPMockFinalVersionTCPServer.h"


@interface TJPNetworkMonitorViewController ()

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;

@property (nonatomic, strong) TJPConcreteSession *session;

@property (nonatomic, strong) UIButton *sendMessageButton; // 用于发送消息的按钮


@end

@implementation TJPNetworkMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"数据监控演示";
    
    // 初始化模拟服务器
    self.mockServer = [[TJPMockFinalVersionTCPServer alloc] init];
    [self.mockServer startWithPort:12345];
    
    
    // 1. 初始化配置
    TJPNetworkConfig *config = [TJPNetworkConfig configWithMaxRetry:5 heartbeat:15.0];

    // 2. 创建会话（中心协调器自动管理）
    self.session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:config];

    // 3. 连接服务器
    [self.session connectToHost:@"127.0.0.1" port:12345];
    
    
    [self setupSendMessageButton];

}

// 设置发送消息按钮
- (void)setupSendMessageButton {
    self.sendMessageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendMessageButton.frame = CGRectMake(100, 200, 200, 50);  // 设置按钮的位置和大小
    [self.sendMessageButton setTitle:@"发送消息" forState:UIControlStateNormal];
    [self.sendMessageButton addTarget:self action:@selector(sendMessageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.sendMessageButton];
}

// 发送消息按钮点击事件
- (void)sendMessageButtonTapped {
    // 4. 发送消息
    NSData *messageData = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    [self.session sendData:messageData];
    NSLog(@"发送消息: %@", [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding]);
}



- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}




@end
