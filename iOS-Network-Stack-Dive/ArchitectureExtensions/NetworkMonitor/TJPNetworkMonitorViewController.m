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
#import "TJPMetricsConsoleReporter.h"

#import "TJPIMClient.h"
#import "TJPTextMessage.h"


@interface TJPNetworkMonitorViewController ()

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;

@property (nonatomic, strong) TJPConcreteSession *session;

@property (nonatomic, strong) UIButton *sendMessageButton;

@property (nonatomic, strong) UITextView *logTextView;


@property (nonatomic, strong) TJPIMClient *client;


@end

@implementation TJPNetworkMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"数据监控演示";
        
    [self setupLogTextView];
    
    [self setupSendMessageButton];
    
    [self setupNetwork];
    
    [[TJPMetricsConsoleReporter sharedInstance] setReportCallback:^(NSString * _Nonnull report) {
        [self logMessage:report];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.mockServer stop];
    [self.session disconnect];
}

- (void)setupNetwork {
    // 初始化模拟服务器
    self.mockServer = [[TJPMockFinalVersionTCPServer alloc] init];
    [self.mockServer startWithPort:12345];
    
    // 1. 初始化配置
    NSString *host = @"127.0.0.1";
    uint16_t port = 12345;
    
//    TJPNetworkConfig *config = [TJPNetworkConfig configWithHost:host port:port maxRetry:5 heartbeat:15.0];
//
//    // 2. 创建会话（中心协调器自动管理）
//    self.session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:config];
//
//    // 3. 连接服务器
//    [self.session connectToHost:host port:port];
    
    self.client = [TJPIMClient shared];
    [self.client connectToHost:host port:port];

    
}

- (void)setupLogTextView {
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 300)];
    self.logTextView.editable = NO;
    self.logTextView.backgroundColor = [UIColor lightGrayColor];
    self.logTextView.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.logTextView];
}

- (void)setupSendMessageButton {
    self.sendMessageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendMessageButton.frame = CGRectMake(100, CGRectGetMaxY(self.logTextView.frame) + 20, 200, 50);
    [self.sendMessageButton setTitle:@"发送消息" forState:UIControlStateNormal];
    [self.sendMessageButton addTarget:self action:@selector(sendMessageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.sendMessageButton];
}

// 发送消息按钮点击事件
- (void)sendMessageButtonTapped {
    // 4. 发送消息
//    NSData *messageData = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
//    [self.session sendData:messageData];
//    NSLog(@"发送消息: %@", [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding]);
    
    TJPTextMessage *textMsg = [[TJPTextMessage alloc] initWithText:@"Hello World!!!!!111112223333"];
    [self.client sendMessage:textMsg];
    NSLog(@"发送消息: %@", textMsg.text);
}




- (void)logMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 获取当前UITextView内容，并追加新的日志消息
        NSString *currentLog = self.logTextView.text;
        NSString *newLog = [currentLog stringByAppendingFormat:@"%@\n", message];
        
        // 更新UITextView的内容
        self.logTextView.text = newLog;
        
        // 滚动到最新日志
        NSRange range = NSMakeRange(self.logTextView.text.length, 0);
        [self.logTextView scrollRangeToVisible:range];
    });
}




@end
