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
#import "TJPNetworkDefine.h"

@interface TJPNetworkMonitorViewController ()

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;
@property (nonatomic, strong) TJPConcreteSession *session;
@property (nonatomic, strong) UIButton *sendMessageButton;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) TJPIMClient *client;

// 新增：状态显示标签
@property (nonatomic, strong) UILabel *connectionStatusLabel;
@property (nonatomic, strong) UIButton *connectButton;
@property (nonatomic, strong) UIButton *disconnectButton;
@property (nonatomic, strong) UIButton *sendMediaButton;

// 新增：定时器用于更新状态显示
@property (nonatomic, strong) NSTimer *statusUpdateTimer;

@end

@implementation TJPNetworkMonitorViewController

- (void)dealloc {
    TJPLogDealloc();
    
    // 清理定时器
    [self.statusUpdateTimer invalidate];
    self.statusUpdateTimer = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"数据监控演示";
        
    [self setupUI];
    [self setupNetwork];
    [self startStatusMonitoring];
    
    // 设置指标报告回调
    [[TJPMetricsConsoleReporter sharedInstance] setReportCallback:^(NSString * _Nonnull report) {
        [self logMessage:report];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.mockServer stop];
    [self.client disconnectAll];
    [self.statusUpdateTimer invalidate];
}

#pragma mark - UI Setup

- (void)setupUI {
    CGFloat currentY = 100;
    
    // 连接状态标签
    [self setupConnectionStatusLabelWithY:currentY];
    currentY += 50;
    
    // 控制按钮
    [self setupControlButtonsWithY:currentY];
    currentY += 120;
    
    // 日志文本视图
    [self setupLogTextViewWithY:currentY];
    currentY = CGRectGetMaxY(self.logTextView.frame) + 20;
    
    // 消息发送按钮
    [self setupMessageButtonsWithY:currentY];
}

- (void)setupConnectionStatusLabelWithY:(CGFloat)y {
    self.connectionStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, self.view.frame.size.width - 20, 30)];
    self.connectionStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.connectionStatusLabel.backgroundColor = [UIColor lightGrayColor];
    self.connectionStatusLabel.text = @"连接状态: 未连接";
    self.connectionStatusLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.view addSubview:self.connectionStatusLabel];
}

- (void)setupControlButtonsWithY:(CGFloat)y {
    // 连接按钮
    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.connectButton.frame = CGRectMake(20, y, 100, 40);
    [self.connectButton setTitle:@"连接" forState:UIControlStateNormal];
    [self.connectButton setBackgroundColor:[UIColor systemBlueColor]];
    [self.connectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.connectButton addTarget:self action:@selector(connectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.connectButton];
    
    // 断开按钮
    self.disconnectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.disconnectButton.frame = CGRectMake(140, y, 100, 40);
    [self.disconnectButton setTitle:@"断开" forState:UIControlStateNormal];
    [self.disconnectButton setBackgroundColor:[UIColor systemRedColor]];
    [self.disconnectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.disconnectButton addTarget:self action:@selector(disconnectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.disconnectButton];
    
    // 状态查询按钮
    UIButton *statusButton = [UIButton buttonWithType:UIButtonTypeSystem];
    statusButton.frame = CGRectMake(260, y, 100, 40);
    [statusButton setTitle:@"查询状态" forState:UIControlStateNormal];
    [statusButton setBackgroundColor:[UIColor systemGreenColor]];
    [statusButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [statusButton addTarget:self action:@selector(queryStatusButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:statusButton];
}

- (void)setupLogTextViewWithY:(CGFloat)y {
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, y, self.view.frame.size.width - 20, 350)];
    self.logTextView.editable = NO;
    self.logTextView.backgroundColor = [UIColor lightGrayColor];
    self.logTextView.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.logTextView];
}

- (void)setupMessageButtonsWithY:(CGFloat)y {
    // 发送文本消息按钮
    self.sendMessageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendMessageButton.frame = CGRectMake(20, y, 150, 40);
    [self.sendMessageButton setTitle:@"发送文本消息" forState:UIControlStateNormal];
    [self.sendMessageButton setBackgroundColor:[UIColor systemOrangeColor]];
    [self.sendMessageButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.sendMessageButton addTarget:self action:@selector(sendTextMessageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendMessageButton];
    
    // 发送媒体消息按钮
    self.sendMediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendMediaButton.frame = CGRectMake(190, y, 150, 40);
    [self.sendMediaButton setTitle:@"发送媒体消息" forState:UIControlStateNormal];
    [self.sendMediaButton setBackgroundColor:[UIColor systemPurpleColor]];
    [self.sendMediaButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.sendMediaButton addTarget:self action:@selector(sendMediaMessageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendMediaButton];
}

#pragma mark - Network Setup

- (void)setupNetwork {
    // 1. 初始化模拟服务器
    self.mockServer = [[TJPMockFinalVersionTCPServer alloc] init];
    [self.mockServer startWithPort:12345];
    [self logMessage:@"📡 模拟服务器已启动，端口: 12345"];
    
    // 2. 获取TJPIMClient实例
    self.client = [TJPIMClient shared];
    [self logMessage:@"🔧 TJPIMClient 初始化完成"];
    
    // 3. 配置自定义路由（可选）
    [self configureCustomRouting];
    
    [self logMessage:@"🚀 网络组件初始化完成，准备连接"];
}

- (void)configureCustomRouting {
    // 示例：配置自定义消息路由
    // [self.client configureRouting:TJPContentTypeCustom toSessionType:TJPSessionTypeDefault];
    [self logMessage:@"⚙️ 消息路由配置完成"];
}

#pragma mark - Button Actions

- (void)connectButtonTapped {
    NSString *host = @"127.0.0.1";
    uint16_t port = 12345;
    
    [self logMessage:@"🔗 开始建立连接..."];
    
    // 建立聊天连接
    [self.client connectToHost:host port:port forType:TJPSessionTypeChat];
    [self logMessage:[NSString stringWithFormat:@"📞 正在连接聊天服务器: %@:%u", host, port]];
    
    // 如果需要，也可以建立媒体连接
    // [self.client connectToHost:host port:port forType:TJPSessionTypeMedia];
    // [self logMessage:[NSString stringWithFormat:@"📺 正在连接媒体服务器: %@:%u", host, port]];
}

- (void)disconnectButtonTapped {
    [self logMessage:@"⚠️ 开始断开连接..."];
    
    // 断开所有连接
    [self.client disconnectAll];
    [self logMessage:@"🔌 已断开所有连接"];
}

- (void)queryStatusButtonTapped {
    [self logMessage:@"📊 查询当前连接状态:"];
    
    // 查询所有连接状态
    NSDictionary *allStates = [self.client getAllConnectionStates];
    
    if (allStates.count == 0) {
        [self logMessage:@"   无活跃连接"];
        return;
    }
    
    for (NSNumber *typeKey in allStates.allKeys) {
        TJPSessionType type = [typeKey unsignedIntegerValue];
        TJPConnectState state = allStates[typeKey];
        NSString *typeName = [self sessionTypeToString:type];
        [self logMessage:[NSString stringWithFormat:@"   %@: %@", typeName, state]];
    }
}

#pragma mark - Message Sending

- (void)sendTextMessageButtonTapped {
    // 检查聊天连接状态
    if (![self.client isConnectedForType:TJPSessionTypeChat]) {
        [self logMessage:@"❌ 聊天连接未建立，无法发送文本消息"];
        return;
    }
    
    // 创建文本消息
    static int messageCounter = 0;
    messageCounter++;
    
    NSString *messageText = [NSString stringWithFormat:@"Hello World! 消息编号: %d", messageCounter];
    TJPTextMessage *textMsg = [[TJPTextMessage alloc] initWithText:messageText];
    
    [self logMessage:[NSString stringWithFormat:@"📝 发送文本消息: %@", messageText]];
    
    // 方式1: 手动指定会话类型发送
    [self.client sendMessage:textMsg throughType:TJPSessionTypeChat];
    
    // 方式2: 自动路由发送（根据消息内容类型自动选择会话）
    // [self.client sendMessageWithAutoRoute:textMsg];
}

- (void)sendMediaMessageButtonTapped {
//    // 检查是否有可用的媒体连接（如果建立了的话）
//    if (![self.client isConnectedForType:TJPSessionTypeMedia]) {
//        // 如果没有媒体连接，使用聊天连接发送
//        if (![self.client isConnectedForType:TJPSessionTypeChat]) {
//            [self logMessage:@"❌ 无可用连接，无法发送媒体消息"];
//            return;
//        }
//        [self logMessage:@"ℹ️ 媒体连接未建立，使用聊天连接发送媒体消息"];
//    }
//    
//    // 创建媒体消息
//    static int mediaCounter = 0;
//    mediaCounter++;
//    
//    NSString *mediaId = [NSString stringWithFormat:@"media_%d", mediaCounter];
//    TJPMediaMessage *mediaMsg = [[TJPMediaMessage alloc] initWithMediaId:mediaId];
//    
//    [self logMessage:[NSString stringWithFormat:@"🎬 发送媒体消息: %@", mediaId]];
//    
//    // 使用自动路由发送（会根据消息类型自动选择合适的会话）
//    [self.client sendMessageWithAutoRoute:mediaMsg];
}

#pragma mark - Status Monitoring

- (void)startStatusMonitoring {
    // 每2秒更新一次状态显示
    self.statusUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                              target:self
                                                            selector:@selector(updateConnectionStatus)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)updateConnectionStatus {
    NSDictionary *allStates = [self.client getAllConnectionStates];
    
    if (allStates.count == 0) {
        self.connectionStatusLabel.text = @"连接状态: 未连接";
        self.connectionStatusLabel.backgroundColor = [UIColor lightGrayColor];
        return;
    }
    
    NSMutableString *statusText = [NSMutableString stringWithString:@"连接状态: "];
    BOOL hasConnected = NO;
    BOOL hasConnecting = NO;
    
    for (NSNumber *typeKey in allStates.allKeys) {
        TJPSessionType type = [typeKey unsignedIntegerValue];
        TJPConnectState state = allStates[typeKey];
        
        if ([self.client isStateConnected:state]) {
            hasConnected = YES;
        } else if ([self.client isStateConnecting:state]) {
            hasConnecting = YES;
        }
        
        NSString *typeName = [self sessionTypeToString:type];
        [statusText appendFormat:@"%@:%@ ", typeName, [self shortStateString:state]];
    }
    
    self.connectionStatusLabel.text = statusText;
    
    // 根据连接状态设置背景色
    if (hasConnected) {
        self.connectionStatusLabel.backgroundColor = [UIColor systemGreenColor];
    } else if (hasConnecting) {
        self.connectionStatusLabel.backgroundColor = [UIColor systemYellowColor];
    } else {
        self.connectionStatusLabel.backgroundColor = [UIColor systemRedColor];
    }
}

#pragma mark - Helper Methods

- (NSString *)sessionTypeToString:(TJPSessionType)type {
    switch (type) {
        case TJPSessionTypeDefault:
            return @"默认";
        case TJPSessionTypeChat:
            return @"聊天";
        case TJPSessionTypeMedia:
            return @"媒体";
        default:
            return [NSString stringWithFormat:@"类型%lu", (unsigned long)type];
    }
}

- (NSString *)shortStateString:(TJPConnectState)state {
    if ([state isEqualToString:TJPConnectStateConnected]) {
        return @"已连接";
    } else if ([state isEqualToString:TJPConnectStateConnecting]) {
        return @"连接中";
    } else if ([state isEqualToString:TJPConnectStateDisconnected]) {
        return @"已断开";
    } else if ([state isEqualToString:TJPConnectStateDisconnecting]) {
        return @"断开中";
    } else {
        return @"未知";
    }
}

- (void)logMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 添加时间戳
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        // 获取当前UITextView内容，并追加新的日志消息
        NSString *currentLog = self.logTextView.text;
        NSString *newLog = [currentLog stringByAppendingFormat:@"[%@] %@\n", timestamp, message];
        
        // 更新UITextView的内容
        self.logTextView.text = newLog;
        
        // 滚动到最新日志
        NSRange range = NSMakeRange(self.logTextView.text.length, 0);
        [self.logTextView scrollRangeToVisible:range];
        
        // 限制日志长度，避免内存问题
        if (newLog.length > 10000) {
            // 保留最后8000个字符
            NSString *trimmedLog = [newLog substringFromIndex:newLog.length - 8000];
            self.logTextView.text = [@"...(日志已截断)\n" stringByAppendingString:trimmedLog];
        }
    });
}

@end
