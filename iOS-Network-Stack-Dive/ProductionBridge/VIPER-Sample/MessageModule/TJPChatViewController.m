//
//  TJPChatViewController.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import "TJPChatViewController.h"
#import <Masonry/Masonry.h>
#import <AudioToolbox/AudioToolbox.h>


#import "TJPChatInputView.h"
#import "TJPConnectionStatusView.h"
#import "TJPChatMessage.h"
#import "TJPChatMessageCell.h"

#import "TJPMockFinalVersionTCPServer.h"
#import "TJPIMClient.h"
#import "TJPSessionProtocol.h"
#import "TJPSessionDelegate.h"
#import "TJPTextMessage.h"
#import "TJPNetworkDefine.h"
#import "TJPMessageTimeoutManager.h"

@interface TJPChatViewController () <UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TJPSessionDelegate, TJPChatInputViewDelegate, TJPChatMessageCellDelegate>

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;
@property (nonatomic, strong) TJPIMClient *client;

// UI组件
@property (nonatomic, strong) TJPConnectionStatusView *statusBarView;

@property (nonatomic, strong) UITableView *messagesTableView;

@property (nonatomic, strong) TJPChatInputView *chatInputView;
@property (nonatomic, strong) MASConstraint *inputViewBottomConstraint;

// 数据
@property (nonatomic, strong) NSMutableArray<TJPChatMessage *> *messages;
@property (nonatomic, assign) NSInteger messageIdCounter;

@property (nonatomic, strong) NSMutableDictionary<NSString *, TJPChatMessage *> *messageMap;


// 状态监控
@property (nonatomic, strong) NSTimer *statusUpdateTimer;

@end

@implementation TJPChatViewController

- (void)dealloc {
    [self.statusUpdateTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"TCP聊天实战";
    self.messageMap = [NSMutableDictionary dictionary];
    
    [self initializeData];
    [self setupNetwork];
    [self setupUI];
    [self startStatusMonitoring];
    [self autoConnect];
    [self setupNotificationListeners];
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

- (void)setupNotificationListeners {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // 监听消息发送成功
    [center addObserver:self selector:@selector(handleMessageSent:) name:kTJPMessageSentNotification object:nil];
    
    // 监听消息发送失败
    [center addObserver:self selector:@selector(handleMessageFailed:) name:kTJPMessageFailedNotification object:nil];
    
    // 监听消息接收
    [center addObserver:self selector:@selector(handleMessageReceived:) name:kTJPMessageReceivedNotification object:nil];
        
    
    // 新增键盘通知监听
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // 状态
    [center addObserver:self selector:@selector(handleMessageStatusUpdated:) name:kTJPMessageStatusUpdateNotification object:nil];

    
          
    NSLog(@"[TJPChatViewController] 监听器设置完成");
}

#pragma mark - UI Setup
- (void)setupUI {
    [self setupStatusBar];
    [self setupMessagesTableView];
    [self setupChatInputView];
    [self setupConstraints];
}

- (void)setupStatusBar {
    self.statusBarView = [[TJPConnectionStatusView alloc] init];
    [self.view addSubview:self.statusBarView];
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

- (void)setupChatInputView {
    self.chatInputView = [[TJPChatInputView alloc] init];
    self.chatInputView.delegate = self;
    [self.view addSubview:self.chatInputView];
}


- (void)setupConstraints {
    // 状态栏约束
    [self.statusBarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.leading.trailing.equalTo(self.view);
        make.height.mas_equalTo(44);
    }];
        
    // 消息列表约束
    [self.messagesTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.statusBarView.mas_bottom);
        make.leading.trailing.equalTo(self.view);
        make.bottom.equalTo(self.chatInputView.mas_top);
    }];
    
    // 聊天输入框约束
    [self.chatInputView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(self.view);
        make.height.mas_equalTo(52);  // 修改：使用正确的最小高度
        self.inputViewBottomConstraint = make.bottom.equalTo(self.view);
    }];
    
}

#pragma mark - Status Monitoring
- (void)startStatusMonitoring {
    self.statusUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateConnectionStatus) userInfo:nil repeats:YES];
}

- (void)updateConnectionStatus {
    TJPConnectionStatus newStatus;
    
    if ([self.client isDisConnectedForType:TJPSessionTypeChat]) {
        newStatus = TJPConnectionStatusDisconnected;
    } else if ([self.client isConnectedForType:TJPSessionTypeChat]) {
        newStatus = TJPConnectionStatusConnected;
    } else {
        newStatus = TJPConnectionStatusReconnecting;
    }
    
    // 更新状态栏
    if (self.statusBarView.status != newStatus) {
        [self.statusBarView updateStatus:newStatus];
    }
    
    // 更新消息计数
    [self.statusBarView updateMessageCount:self.messages.count];
    
    // 计算各种状态的消息数量
    NSInteger sendingCount = 0;
    NSInteger failedCount = 0;
    
    for (TJPChatMessage *message in self.messages) {
        if (message.isFromSelf) {
            switch (message.status) {
                case TJPChatMessageStatusSending:
                    sendingCount++;
                    break;
                case TJPChatMessageStatusFailed:
                    failedCount++;
                    break;
                default:
                    break;
            }
        }
    }
    
    // 更新待发送消息计数（发送中 + 失败的）
    [self.statusBarView updatePendingCount:sendingCount + failedCount];
    
    // 如果有失败的消息，可以在状态栏显示额外提示
    if (failedCount > 0) {
        NSLog(@"[TJPChatViewController] ⚠️ 有 %ld 条消息发送失败，可点击重试", (long)failedCount);
    }
}

#pragma mark - Private Method
- (void)showTemporaryFailureNotification {
    // 显示临时的发送失败提示
    UIView *notificationView = [[UIView alloc] init];
    notificationView.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.9];
    notificationView.layer.cornerRadius = 8;
    
    UILabel *notificationLabel = [[UILabel alloc] init];
    notificationLabel.text = @"消息发送失败，请点击重试";
    notificationLabel.textColor = [UIColor whiteColor];
    notificationLabel.font = [UIFont systemFontOfSize:14];
    notificationLabel.textAlignment = NSTextAlignmentCenter;
    
    [notificationView addSubview:notificationLabel];
    [self.view addSubview:notificationView];
    
    [notificationView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.chatInputView.mas_top).offset(-16);
        make.height.mas_equalTo(40);
    }];
    
    [notificationLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(notificationView);
        make.leading.equalTo(notificationView.mas_leading).offset(16);
        make.trailing.equalTo(notificationView.mas_trailing).offset(-16);
    }];
    
    // 显示和隐藏动画
    notificationView.alpha = 0;
    notificationView.transform = CGAffineTransformMakeTranslation(0, 20);
    
    [UIView animateWithDuration:0.3 animations:^{
        notificationView.alpha = 1;
        notificationView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // 3秒后自动隐藏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                notificationView.alpha = 0;
                notificationView.transform = CGAffineTransformMakeTranslation(0, -20);
            } completion:^(BOOL finished) {
                [notificationView removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - Actions
- (void)imageButtonTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - Notification
- (void)handleMessageSent:(NSNotification *)notification {
    NSString *messageId = notification.userInfo[@"messageId"];
    NSNumber *sequence = notification.userInfo[@"sequence"];
    
    TJPChatMessage *chatMessage = self.messageMap[messageId];
    if (chatMessage) {
        NSLog(@"[TJPChatViewController] ✅ 消息发送成功: %@ (序列:%@)", messageId, sequence);
        
        chatMessage.status = TJPChatMessageStatusSent;
        chatMessage.timestamp = [NSDate date];
        [self updateMessageCell:chatMessage];
        
        // 更新状态栏（减少待发送计数）
        [self updateConnectionStatus];
        
        // 可选：成功反馈
        [self playMessageSentSound];
        
        // 从超时队列中移除
        [[TJPMessageTimeoutManager sharedManager] removeMessageFromTimeoutCheck:chatMessage];
        
        // 模拟一段时间后变为已读状态
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (chatMessage.status == TJPChatMessageStatusSent) {
                chatMessage.status = TJPChatMessageStatusRead;
                [self updateMessageCell:chatMessage];
            }
        });
    }
}

- (void)handleMessageReceived:(NSNotification *)notification {
//    NSData *data = notification.userInfo[@"data"];
//    NSNumber *sequence = notification.userInfo[@"sequence"];
//    
//    // 解析消息内容（这里简化为文本）
//    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    
//    NSLog(@"[Chat] 📥 收到消息: %@ (序列:%@)", text, sequence);
//    
//    // 创建接收消息
//    TJPChatMessage *receivedMessage = [self createReceivedMessageWithContent:text];
//    [self.messages addObject:receivedMessage];
//    [self reloadMessagesAndScrollToBottom];
//    
//    // 可选：新消息提示
//    [self playMessageReceivedSound];
//    [self updateBadgeCount];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    CGFloat keyboardHeight = keyboardFrame.size.height;
    
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)curve animations:^{
        self.inputViewBottomConstraint.offset = -keyboardHeight;
        [self.view layoutIfNeeded];
        [self scrollToBottomAnimated:NO];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)curve animations:^{
        self.inputViewBottomConstraint.offset = 0;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)handleMessageStatusUpdated:(NSNotification *)notification {
    TJPChatMessage *message = notification.object;
    
    [self updateMessageCell:message];
}

- (void)playMessageSentSound {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 播放发送成功音效
        AudioServicesPlaySystemSound(1003);
    });
}

- (void)playMessageReceivedSound {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 播放接收消息音效
        AudioServicesPlaySystemSound(1002);
    });
}



- (void)updateMessageCell:(TJPChatMessage *)message {
    // 找到对应的cell并更新UI
    NSUInteger index = [self.messages indexOfObject:message];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messagesTableView reloadRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
        });
    }
}


- (void)handleMessageFailed:(NSNotification *)notification {
    NSString *messageId = notification.userInfo[@"messageId"];
    NSError *error = notification.userInfo[@"error"];
    
    TJPChatMessage *chatMessage = self.messageMap[messageId];
    if (chatMessage) {
        NSLog(@"[TJPChatViewController] ❌ 消息发送失败: %@ - %@", messageId, error.localizedDescription);
        
        chatMessage.status = TJPChatMessageStatusFailed;
//        chatMessage.failureReason = error.localizedDescription;
        [self updateMessageCell:chatMessage];
        
        // 更新状态栏
        [self updateConnectionStatus];
        
        // 显示失败提示
        [self showTemporaryFailureNotification];
    }
}

#pragma mark - TJPChatInputViewDelegate
- (void)chatInputView:(TJPChatInputView *)inputView didSendText:(NSString *)text {
    [self sendTextMessage:text];
}

- (void)chatInputViewDidTapImageButton:(TJPChatInputView *)inputView {
    [self imageButtonTapped];
}

- (void)chatInputView:(TJPChatInputView *)inputView didChangeHeight:(CGFloat)height {
    // 更新输入框高度约束
    [self.chatInputView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(height);
    }];
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
        [self scrollToBottomAnimated:NO];
    }];
}

- (void)chatInputViewDidBeginEditing:(TJPChatInputView *)inputView {
    // 输入开始时，滚动到底部
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

#pragma mark - Message Handling
- (void)sendTextMessage:(NSString *)text {
    // 创建聊天消息对象
    TJPChatMessage *chatMessage = [self createChatMessageWithContent:text type:TJPChatMessageTypeText image:nil];
    chatMessage.status = TJPChatMessageStatusSending;
    
    // 添加到消息列表
    [self.messages addObject:chatMessage];
    [self reloadMessagesAndScrollToBottom];
    
    // 更新状态栏
    [self updateConnectionStatus];
    
    // 创建网络消息对象并发送
    TJPTextMessage *networkMessage = [[TJPTextMessage alloc] initWithText:text];
    
    // 使用TJPIMClient发送消息
    NSString *messageId = [self.client sendMessage:networkMessage throughType:TJPSessionTypeChat encryptType:TJPEncryptTypeCRC32 compressType:TJPCompressTypeZlib completion:^(NSString * msgId, NSError *error) {
        if (!error) {
            self.messageMap[msgId] = chatMessage;
            chatMessage.messageId = msgId;
            NSLog(@"[TJPChatViewController]  消息已提交: 内容: %@ 消息ID:%@", text, msgId);
        }else {
            // 发送失败，立即更新状态
            dispatch_async(dispatch_get_main_queue(), ^{
                chatMessage.status = TJPChatMessageStatusFailed;
                [self updateMessageCell:chatMessage];
                [self updateConnectionStatus];
                
                // 显示发送失败提示
                [self showSendFailureAlert];
            });
        }
    }];
    
    [self reloadMessagesAndScrollToBottom];
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


- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.messages.count > 0) {
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.messagesTableView scrollToRowAtIndexPath:lastIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

#pragma mark - TJPSessionDelegate

// === 状态回调 ===
- (void)session:(id<TJPSessionProtocol>)session didChangeState:(TJPConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 根据连接状态更新UI
        if ([state isEqualToString:TJPConnectStateConnected]) {
            [self.statusBarView updateStatus:TJPConnectionStatusConnected];
            [self logConnectionMessage:@"🟢 TCP连接已建立"];
            [self handleConnectionEstablished];
        } else if ([state isEqualToString:TJPConnectStateConnecting]) {
            [self.statusBarView updateStatus:TJPConnectionStatusConnecting];
            [self logConnectionMessage:@"🟠 正在建立连接..."];
        } else if ([state isEqualToString:TJPConnectStateDisconnected]) {
            [self.statusBarView updateStatus:TJPConnectionStatusDisconnected];
            [self logConnectionMessage:@"🔴 连接已断开"];
            [self handleConnectionLost];
        }
        
        // 同时更新消息计数
        [self.statusBarView updateMessageCount:self.messages.count];
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
    
    [self scrollToBottomAnimated:YES];
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
    cell.delegate = self;
    
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

#pragma mark - TJPChatMessageCellDelegate (新增)
- (void)chatMessageCell:(TJPChatMessageCell *)cell didRequestRetryForMessage:(TJPChatMessage *)message {
    NSLog(@"[TJPChatViewController] 用户请求重试消息: %@", message.content);
    
    // 确认是失败的消息
    if (message.status != TJPChatMessageStatusFailed) {
        NSLog(@"[TJPChatViewController] 消息状态不是失败状态，无法重试");
        return;
    }
    
    // 重置消息状态为发送中
    message.status = TJPChatMessageStatusSending;
    
    // 更新Cell显示
    [self updateMessageCell:message];
    
    // 更新状态栏（减少失败消息计数）
    [self updateConnectionStatus];
    
    // 根据消息类型重新发送
    if (message.messageType == TJPChatMessageTypeText) {
        [self retryTextMessage:message];
    } else if (message.messageType == TJPChatMessageTypeImage) {
//        [self retryImageMessage:message];
    }
}

- (void)retryTextMessage:(TJPChatMessage *)message {
    // 创建网络消息对象
    TJPTextMessage *networkMessage = [[TJPTextMessage alloc] initWithText:message.content];
    
    // 发送消息
    NSString *messageId = [self.client sendMessage:networkMessage
                                       throughType:TJPSessionTypeChat
                                       encryptType:TJPEncryptTypeCRC32
                                      compressType:TJPCompressTypeZlib
                                        completion:^(NSString *msgId, NSError *error) {
        if (!error) {
            // 更新消息映射
            if (message.messageId && self.messageMap[message.messageId]) {
                [self.messageMap removeObjectForKey:message.messageId];
            }
            self.messageMap[msgId] = message;
            message.messageId = msgId;
            
            NSLog(@"[TJPChatViewController] ✅ 重试消息已提交: %@", msgId);
        } else {
            // 重试也失败了
            dispatch_async(dispatch_get_main_queue(), ^{
                message.status = TJPChatMessageStatusFailed;
                [self updateMessageCell:message];
                [self updateConnectionStatus];
                
                // 显示重试失败提示
                [self showRetryFailureAlert];
            });
        }
    }];
}

- (void)showRetryFailureAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重试失败"
                                                                   message:@"消息重试发送失败，请检查网络连接后再试"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSendFailureAlertWithRetryOption {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"发送失败"
                                                                   message:@"消息发送失败，你可以点击消息旁的重试按钮重新发送"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}


@end
