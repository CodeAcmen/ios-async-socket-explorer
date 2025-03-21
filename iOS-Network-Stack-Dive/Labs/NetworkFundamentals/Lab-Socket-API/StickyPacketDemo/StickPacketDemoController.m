//
//  StickPacketDemoController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import "StickPacketDemoController.h"
#import "SocketChatServer.h"
#import "SocketChatClient.h"

@interface StickPacketDemoController () <SocketChatServerDelegate>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UITextView *messageTextView;


@property (nonatomic, strong) SocketChatServer *server;
@property (nonatomic, strong) SocketChatClient *client;


@end

@implementation StickPacketDemoController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.server = [[SocketChatServer alloc] init];
    self.server.delegate = self;
    [self.server startServerOnPort:8080];
    
    self.client = [[SocketChatClient alloc] init];
    [self.client connectToHost:@"127.0.0.1" port:8080];
    
    [self setupUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 停止服务器
    [self.server stopServer];
}

- (void)setupUI {
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 100, 300, 30)];
    self.titleLabel.text = @"粘包问题演示";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:self.titleLabel];
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(self.view.bounds.size.width / 2 - 50, CGRectGetMaxY(self.titleLabel.frame) + 20, 100, 40);
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendButton];
    
    self.messageTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 300, 350, 200)];
    self.messageTextView.font = [UIFont systemFontOfSize:14];
    self.messageTextView.textColor = [UIColor blackColor];
    self.messageTextView.backgroundColor = [UIColor lightGrayColor];
    self.messageTextView.editable = NO;
    [self.view addSubview:self.messageTextView];
}


- (void)sendMessage {
    [self.client sendMessage:@"Message 1"];

    NSString *message = @"Hello, Server! This is a test message for sticky packet problem.";
    [self.client sendMessage:message];

    [self.client sendMessage:@"Message 2"];
    [self.client sendMessage:@"Message 3"];
}


#pragma mark - SocketChatServerDelegate
- (void)didReceiveMessageFromClient:(NSString *)message {
    self.messageTextView.text = [self.messageTextView.text stringByAppendingFormat:@"Server: \n%@", message];
}


@end
