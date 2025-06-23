//
//  TJPChatViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import "TJPChatViewController.h"
#import "TJPMockFinalVersionTCPServer.h"
#import "TJPIMClient.h"
#import "TJPChatMessage.h"
#import "TJPChatMessageCell.h"
#import "TJPTextMessage.h"
#import "TJPSessionProtocol.h"
#import "TJPSessionDelegate.h"

@interface TJPChatViewController () <UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TJPSessionDelegate>

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;
@property (nonatomic, strong) TJPIMClient *client;

// UI组件
@property (nonatomic, strong) UIView *statusBarView;
@property (nonatomic, strong) UILabel *connectionStatusLabel;
@property (nonatomic, strong) UITableView *messagesTableView;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UITextView *messageInputTextView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *imageButton;

// 数据
@property (nonatomic, strong) NSMutableArray<TJPChatMessage *> *messages;
@property (nonatomic, assign) NSInteger messageIdCounter;

// 状态监控
@property (nonatomic, strong) NSTimer *statusUpdateTimer;

@end

@implementation TJPChatViewController

- (void)dealloc {
    [self.statusUpdateTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"TCP聊天实战";
    
    [self initializeData];
    [self setupNetwork];
    [self setupUI];
    [self startStatusMonitoring];
    [self autoConnect];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.mockServer stop];
    [self.client disconnectAll];
    [self.statusUpdateTimer invalidate];
}

#pragma mark - Initialization

- (void)initializeData {
    self.messages = [NSMutableArray array];
    self.messageIdCounter = 1;
    
    // 添加示例消息
    [self addWelcomeMessages];
}

- (void)addWelcomeMessages {
    TJPChatMessage *welcomeMsg = [[TJPChatMessage alloc] init];
    welcomeMsg.messageId = @"welcome_1";
    welcomeMsg.content = @"欢迎来到TCP聊天实战演示！";
    welcomeMsg.isFromSelf = NO;
    welcomeMsg.timestamp = [NSDate date];
    welcomeMsg.messageType = TJPChatMessageTypeText;
    welcomeMsg.status = TJPChatMessageStatusSent;
    [self.messages addObject:welcomeMsg];
    
    TJPChatMessage *infoMsg = [[TJPChatMessage alloc] init];
    infoMsg.messageId = @"info_1";
    infoMsg.content = @"你可以发送文本消息和图片，体验完整的TCP通信流程";
    infoMsg.isFromSelf = NO;
    infoMsg.timestamp = [NSDate dateWithTimeIntervalSinceNow:1];
    infoMsg.messageType = TJPChatMessageTypeText;
    infoMsg.status = TJPChatMessageStatusSent;
    [self.messages addObject:infoMsg];
}

#pragma mark - Network Setup

- (void)setupNetwork {
    // 启动模拟服务器
    self.mockServer = [[TJPMockFinalVersionTCPServer alloc] init];
    [self.mockServer startWithPort:12345];
    
    // 获取IM客户端实例
    self.client = [TJPIMClient shared];
    
}

- (void)setupSessionDelegate {

}

- (void)autoConnect {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.client connectToHost:@"127.0.0.1" port:12345 forType:TJPSessionTypeChat];
        
        // 连接后尝试获取session设置代理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupSessionDelegateAfterConnection];
        });
    });
}

- (void)setupSessionDelegateAfterConnection {
    
    

}

#pragma mark - UI Setup

- (void)setupUI {
    [self setupStatusBar];
    [self setupMessagesTableView];
    [self setupInputContainer];
    [self setupConstraints];
}

- (void)setupStatusBar {
    self.statusBarView = [[UIView alloc] init];
    self.statusBarView.backgroundColor = [UIColor systemGray6Color];
    [self.view addSubview:self.statusBarView];
    
    self.connectionStatusLabel = [[UILabel alloc] init];
    self.connectionStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.connectionStatusLabel.font = [UIFont systemFontOfSize:14];
    self.connectionStatusLabel.text = @"连接状态: 连接中...";
    [self.statusBarView addSubview:self.connectionStatusLabel];
}

- (void)setupMessagesTableView {
    self.messagesTableView = [[UITableView alloc] init];
    self.messagesTableView.delegate = self;
    self.messagesTableView.dataSource = self;
    self.messagesTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.messagesTableView.backgroundColor = [UIColor systemBackgroundColor];
    [self.messagesTableView registerClass:[TJPChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];
    [self.view addSubview:self.messagesTableView];
}

- (void)setupInputContainer {
    self.inputContainerView = [[UIView alloc] init];
    self.inputContainerView.backgroundColor = [UIColor systemGray6Color];
    [self.view addSubview:self.inputContainerView];
    
    // 图片按钮
    self.imageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.imageButton setTitle:@"📷" forState:UIControlStateNormal];
    self.imageButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.imageButton addTarget:self action:@selector(imageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.imageButton];
    
    // 输入框
    self.messageInputTextView = [[UITextView alloc] init];
    self.messageInputTextView.font = [UIFont systemFontOfSize:16];
    self.messageInputTextView.layer.cornerRadius = 20;
    self.messageInputTextView.layer.borderWidth = 1;
    self.messageInputTextView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.messageInputTextView.textContainerInset = UIEdgeInsetsMake(8, 12, 8, 12);
    [self.inputContainerView addSubview:self.messageInputTextView];
    
    // 发送按钮
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor systemBlueColor];
    self.sendButton.layer.cornerRadius = 20;
    [self.sendButton addTarget:self action:@selector(sendButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.sendButton];
}

- (void)setupConstraints {
    // 使用Frame布局（也可以改用Auto Layout）
    CGFloat statusBarHeight = 40;
    CGFloat inputContainerHeight = 80;
    
    self.statusBarView.frame = CGRectMake(0, self.view.safeAreaInsets.top,
                                         self.view.frame.size.width, statusBarHeight);
    
    self.connectionStatusLabel.frame = self.statusBarView.bounds;
    
    CGFloat tableViewY = CGRectGetMaxY(self.statusBarView.frame);
    CGFloat tableViewHeight = self.view.frame.size.height - tableViewY - inputContainerHeight - self.view.safeAreaInsets.bottom;
    
    self.messagesTableView.frame = CGRectMake(0, tableViewY, self.view.frame.size.width, tableViewHeight);
    
    self.inputContainerView.frame = CGRectMake(0, CGRectGetMaxY(self.messagesTableView.frame),
                                              self.view.frame.size.width, inputContainerHeight);
    
    // 输入容器内部布局
    CGFloat margin = 10;
    self.imageButton.frame = CGRectMake(margin, margin, 40, 40);
    
    self.sendButton.frame = CGRectMake(self.inputContainerView.frame.size.width - 70 - margin,
                                      margin, 70, 40);
    
    CGFloat textViewX = CGRectGetMaxX(self.imageButton.frame) + margin;
    CGFloat textViewWidth = CGRectGetMinX(self.sendButton.frame) - textViewX - margin;
    self.messageInputTextView.frame = CGRectMake(textViewX, margin, textViewWidth, 40);
}

#pragma mark - Status Monitoring

- (void)startStatusMonitoring {
    self.statusUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                              target:self
                                                            selector:@selector(updateConnectionStatus)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)updateConnectionStatus {
    if ([self.client isConnectedForType:TJPSessionTypeChat]) {
        self.connectionStatusLabel.text = @"🟢 TCP连接已建立 - 可以正常聊天";
        self.connectionStatusLabel.textColor = [UIColor systemGreenColor];
        self.sendButton.enabled = YES;
        self.imageButton.enabled = YES;
    } else {
        self.connectionStatusLabel.text = @"🔴 TCP连接断开 - 正在重连...";
        self.connectionStatusLabel.textColor = [UIColor systemRedColor];
        self.sendButton.enabled = NO;
        self.imageButton.enabled = NO;
    }
}

#pragma mark - Actions

- (void)sendButtonTapped {
    NSString *messageText = [self.messageInputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (messageText.length == 0) {
        return;
    }
    
    [self sendTextMessage:messageText];
    self.messageInputTextView.text = @"";
}

- (void)imageButtonTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - Message Handling

- (void)sendTextMessage:(NSString *)text {
    // 创建聊天消息对象
    TJPChatMessage *chatMessage = [self createChatMessageWithContent:text type:TJPChatMessageTypeText image:nil];
    chatMessage.status = TJPChatMessageStatusSending;
    
    // 添加到消息列表
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
    
    // 创建网络消息对象并发送
    TJPTextMessage *networkMessage = [[TJPTextMessage alloc] initWithText:text];
    
    // 使用TJPIMClient发送消息
    [self.client sendMessage:networkMessage throughType:TJPSessionTypeChat];
    
    // 模拟发送成功（实际应该通过代理回调处理）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        chatMessage.status = TJPChatMessageStatusSent;
        [self reloadMessagesAndScrollToBottom];
    });
}

- (void)sendImageMessage:(UIImage *)image {
//    // 创建聊天消息对象
//    TJPChatMessage *chatMessage = [self createChatMessageWithContent:@"[图片]" type:TJPChatMessageTypeImage image:image];
//    chatMessage.status = TJPChatMessageStatusSending;
//    
//    // 添加到消息列表
//    [self.messages addObject:chatMessage];
//    [self reloadMessagesAndScrollToBottom];
//    
//    // 将图片转换为数据
//    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
//    
//    // 发送图片消息（根据你的实际API调整）
//    uint32_t messageSequence = [self.client sendImageData:imageData throughType:TJPSessionTypeChat];
//    
//    // 跟踪发送中的消息
//    if (messageSequence > 0) {
//        self.sendingMessages[@(messageSequence)] = chatMessage;
//    } else {
//        // 发送失败
//        chatMessage.status = TJPChatMessageStatusFailed;
//        [self reloadMessagesAndScrollToBottom];
//        [self showSendFailureAlert];
//    }
}

#pragma mark - TJPSessionDelegate

// === 状态回调 ===
- (void)session:(id<TJPSessionProtocol>)session didChangeState:(TJPConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateConnectionStatus];
        
        if ([state isEqualToString:TJPConnectStateConnected]) {
            [self logConnectionMessage:@"🟢 TCP连接已建立"];
            // 连接成功，可以尝试将之前发送中的消息标记为已发送
            [self handleConnectionEstablished];
        } else if ([state isEqualToString:TJPConnectStateConnecting]) {
            [self logConnectionMessage:@"🟡 正在建立连接..."];
        } else if ([state isEqualToString:TJPConnectStateDisconnected]) {
            [self logConnectionMessage:@"🔴 连接已断开"];
            // 连接断开，将发送中的消息标记为失败
            [self handleConnectionLost];
        }
    });
}

- (void)session:(id<TJPSessionProtocol>)session didDisconnectWithReason:(TJPDisconnectReason)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self logConnectionMessage:[NSString stringWithFormat:@"⚠️ 连接断开，原因: %@", reason]];
        [self updateConnectionStatus];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self logConnectionMessage:[NSString stringWithFormat:@"❌ 连接失败: %@", error.localizedDescription]];
        [self updateConnectionStatus];
    });
}

- (void)sessionDidForceDisconnect:(id<TJPSessionProtocol>)session {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self logConnectionMessage:@"⚠️ 连接被强制断开"];
        [self updateConnectionStatus];
    });
}

// === 内容回调 ===
- (void)session:(id<TJPSessionProtocol>)session didReceiveText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedTextMessage:text];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedImageMessage:image];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveAudio:(NSData *)audioData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedAudioMessage:audioData];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveVideo:(NSData *)videoData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedVideoMessage:videoData];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveFile:(NSData *)fileData filename:(NSString *)filename {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedFileMessage:fileData filename:filename];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveLocation:(CLLocation *)location {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedLocationMessage:location];
    });
}

- (void)session:(id<TJPSessionProtocol>)session didReceiveCustomData:(NSData *)data withType:(uint16_t)customType {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleReceivedCustomMessage:data customType:customType];
    });
}

// 发送消息失败
- (void)session:(id<TJPSessionProtocol>)session didFailToSendMessageWithSequence:(uint32_t)sequence error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[TJPChatViewController] 消息发送失败，序列号: %u, 错误: %@", sequence, error.localizedDescription);
        [self showSendFailureAlert];
        
        // 可以在这里找到对应的消息并更新状态为失败
        // 由于简化了消息跟踪，这里暂时只显示提示
    });
}

// 版本协商完成
- (void)session:(id<TJPSessionProtocol>)session didCompleteVersionNegotiation:(uint16_t)version features:(uint16_t)features {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self logConnectionMessage:[NSString stringWithFormat:@"🤝 协议协商完成 - 版本: %d, 特性: %d", version, features]];
    });
}

// 原始数据回调
- (void)session:(id<TJPSessionProtocol>)session didReceiveRawData:(NSData *)data {
    // 通常不需要处理原始数据，除非有特殊需求
}

#pragma mark - Message Handling Helpers

- (void)handleReceivedTextMessage:(NSString *)text {
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:text type:TJPChatMessageTypeText image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedImageMessage:(UIImage *)image {
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:@"[图片]" type:TJPChatMessageTypeImage image:image];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedAudioMessage:(NSData *)audioData {
    // 处理音频消息
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:@"[语音消息]" type:TJPChatMessageTypeAudio image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedVideoMessage:(NSData *)videoData {
    // 处理视频消息
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:@"[视频消息]" type:TJPChatMessageTypeVideo image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedFileMessage:(NSData *)fileData filename:(NSString *)filename {
    // 处理文件消息
    NSString *content = [NSString stringWithFormat:@"[文件: %@]", filename];
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:content type:TJPChatMessageTypeFile image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedLocationMessage:(CLLocation *)location {
    // 处理位置消息
    NSString *content = [NSString stringWithFormat:@"[位置: %.6f, %.6f]", location.coordinate.latitude, location.coordinate.longitude];
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:content type:TJPChatMessageTypeText image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (void)handleReceivedCustomMessage:(NSData *)data customType:(uint16_t)customType {
    // 处理自定义消息
    NSString *content = [NSString stringWithFormat:@"[自定义消息 类型:%d]", customType];
    TJPChatMessage *chatMessage = [self createReceivedMessageWithContent:content type:TJPChatMessageTypeText image:nil];
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
}

- (TJPChatMessage *)createReceivedMessageWithContent:(NSString *)content type:(TJPChatMessageType)type image:(UIImage *)image {
    TJPChatMessage *message = [[TJPChatMessage alloc] init];
    message.messageId = [NSString stringWithFormat:@"received_%ld", (long)self.messageIdCounter++];
    message.content = content;
    message.isFromSelf = NO;
    message.timestamp = [NSDate date];
    message.messageType = type;
    message.image = image;
    message.status = TJPChatMessageStatusSent;
    return message;
}

- (void)logConnectionMessage:(NSString *)message {
    // 可以在这里添加连接日志显示逻辑
    NSLog(@"连接状态: %@", message);
}

- (void)handleConnectionEstablished {
    // 连接建立后的处理逻辑
    NSLog(@"[TJPChatViewController] TCP连接已建立，可以正常发送消息");
}

- (void)handleConnectionLost {
    // 连接丢失后的处理逻辑
    NSLog(@"[TJPChatViewController] TCP连接丢失");
}

- (TJPChatMessage *)createChatMessageWithContent:(NSString *)content type:(TJPChatMessageType)type image:(UIImage *)image {
    TJPChatMessage *message = [[TJPChatMessage alloc] init];
    message.messageId = [NSString stringWithFormat:@"msg_%ld", (long)self.messageIdCounter++];
    message.content = content;
    message.isFromSelf = YES;
    message.timestamp = [NSDate date];
    message.messageType = type;
    message.image = image;
    return message;
}

- (void)reloadMessagesAndScrollToBottom {
    [self.messagesTableView reloadData];
    
    if (self.messages.count > 0) {
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.messagesTableView scrollToRowAtIndexPath:lastIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)showSendFailureAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"发送失败"
                                                                   message:@"消息发送失败，请检查网络连接"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TJPChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell" forIndexPath:indexPath];
    TJPChatMessage *message = self.messages[indexPath.row];
    [cell configureWithMessage:message];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    TJPChatMessage *message = self.messages[indexPath.row];
    return [TJPChatMessageCell heightForMessage:message inWidth:tableView.frame.size.width];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        [self sendImageMessage:selectedImage];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
