//
//  TJPChatMessageCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import "TJPChatMessageCell.h"
#import "TJPChatMessage.h"
#import "TJPMessageStatusIndicator.h"
#import "TJPMessageTimeoutManager.h"


@interface TJPChatMessageCell () <TJPMessageStatusIndicatorDelegate>

@end

@implementation TJPChatMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    
    // 气泡背景
    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.layer.cornerRadius = 12;
    [self.contentView addSubview:self.bubbleView];
    
    // 消息文本
    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.font = [UIFont systemFontOfSize:16];
    [self.bubbleView addSubview:self.messageLabel];
    
    // 消息图片
    self.messageImageView = [[UIImageView alloc] init];
    self.messageImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.messageImageView.clipsToBounds = YES;
    self.messageImageView.layer.cornerRadius = 8;
    self.messageImageView.hidden = YES;
    [self.bubbleView addSubview:self.messageImageView];
    
    // 时间标签
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [UIFont systemFontOfSize:12];
    self.timeLabel.textColor = [UIColor grayColor];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.timeLabel];
    
    // 加载指示器
    self.statusIndicator = [[TJPMessageStatusIndicator alloc] init];
    self.statusIndicator.delegate = self;
    self.statusIndicator.hidden = YES; // 默认隐藏，只对自己的消息显示
    [self.contentView addSubview:self.statusIndicator];

}

- (void)configureWithMessage:(TJPChatMessage *)message {
    self.chatMessage = message;
    
    // 时间格式化
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    self.timeLabel.text = [formatter stringFromDate:message.timestamp];
    
    // 根据消息类型配置UI
    if (message.messageType == TJPChatMessageTypeText) {
        self.messageLabel.text = message.content;
        self.messageLabel.hidden = NO;
        self.messageImageView.hidden = YES;
    } else if (message.messageType == TJPChatMessageTypeImage) {
        self.messageImageView.image = message.image;
        self.messageImageView.hidden = NO;
        self.messageLabel.hidden = YES;
    }
    
    // 根据发送方设置样式
    if (message.isFromSelf) {
        // 自己发送的消息 - 右侧，蓝色
        self.bubbleView.backgroundColor = [UIColor systemBlueColor];
        self.messageLabel.textColor = [UIColor whiteColor];
        // 配置状态指示器
        [self configureStatusIndicatorForMessage:message];
    } else {
        // 接收的消息 - 左侧，灰色
        self.bubbleView.backgroundColor = [UIColor systemGray5Color];
        self.messageLabel.textColor = [UIColor blackColor];
        
        self.statusIndicator.hidden = YES;
    }
    
    [self setNeedsLayout];
}

- (void)configureStatusIndicatorForMessage:(TJPChatMessage *)message {
    self.statusIndicator.hidden = NO;
    self.statusIndicator.messageId = message.messageId;
    
    // 根据消息状态配置指示器
    TJPMessageIndicatorStatus indicatorStatus;
    BOOL animated = YES;
    
    switch (message.status) {
        case TJPChatMessageStatusSending:
            indicatorStatus = TJPMessageIndicatorStatusSending;
            break;
        case TJPChatMessageStatusSent:
            indicatorStatus = TJPMessageIndicatorStatusSent;
            break;
        case TJPChatMessageStatusFailed:
            indicatorStatus = TJPMessageIndicatorStatusFailed;
            break;
        case TJPChatMessageStatusRead:
            indicatorStatus = TJPMessageIndicatorStatusRead;
            break;
        default:
            indicatorStatus = TJPMessageIndicatorStatusSending;
            animated = NO;
            break;
    }
    
    [self.statusIndicator updateStatus:indicatorStatus animated:animated];
    
    // 启动超时检查
    if (message.status == TJPChatMessageStatusSending) {
        [[TJPMessageTimeoutManager sharedManager] addMessageForTimeoutCheck:message];
    }
}



- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat margin = 15;
    CGFloat bubbleMaxWidth = self.contentView.frame.size.width * 0.7;
    
    // 时间标签
    self.timeLabel.frame = CGRectMake(0, 5, self.contentView.frame.size.width, 20);
    
    CGSize messageSize = CGSizeZero;
    if (!self.messageLabel.hidden) {
        messageSize = [self.messageLabel.text boundingRectWithSize:CGSizeMake(bubbleMaxWidth - 20, CGFLOAT_MAX)
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                        attributes:@{NSFontAttributeName: self.messageLabel.font}
                                                           context:nil].size;
        messageSize.width = MIN(messageSize.width + 20, bubbleMaxWidth);
        messageSize.height += 20;
    } else if (!self.messageImageView.hidden) {
        messageSize = CGSizeMake(150, 150); // 固定图片大小
    }
    
    // 气泡位置
    CGFloat bubbleY = CGRectGetMaxY(self.timeLabel.frame) + 5;
    if (self.chatMessage.isFromSelf) {
        self.bubbleView.frame = CGRectMake(self.contentView.frame.size.width - messageSize.width - margin,
                                          bubbleY, messageSize.width, messageSize.height);
        
        // 状态指示器位置（在气泡右侧）
        if (!self.statusIndicator.hidden) {
                    CGSize indicatorSize = [TJPMessageStatusIndicator indicatorSize];
                    self.statusIndicator.frame = CGRectMake(CGRectGetMinX(self.bubbleView.frame) - indicatorSize.width - 8, CGRectGetMaxY(self.bubbleView.frame) - indicatorSize.height - 5, indicatorSize.width, indicatorSize.height);
                }
    } else {
        // 左侧
        self.bubbleView.frame = CGRectMake(margin, bubbleY, messageSize.width, messageSize.height);
    }
    
    // 内容位置
    if (!self.messageLabel.hidden) {
        self.messageLabel.frame = CGRectMake(10, 10, messageSize.width - 20, messageSize.height - 20);
    }
    if (!self.messageImageView.hidden) {
        self.messageImageView.frame = CGRectMake(10, 10, messageSize.width - 20, messageSize.height - 20);
    }
}

+ (CGFloat)heightForMessage:(TJPChatMessage *)message inWidth:(CGFloat)width {
    CGFloat bubbleMaxWidth = width * 0.7;
    CGFloat height = 30; // 时间标签 + 间距
    
    if (message.messageType == TJPChatMessageTypeText) {
        CGSize messageSize = [message.content boundingRectWithSize:CGSizeMake(bubbleMaxWidth - 20, CGFLOAT_MAX)
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16]}
                                                           context:nil].size;
        height += messageSize.height + 30; // 文本高度 + 气泡内边距
    } else if (message.messageType == TJPChatMessageTypeImage) {
        height += 170; // 固定图片高度 + 气泡内边距
    }
    
    return height + 15; // 底部间距
}

#pragma mark - TJPMessageStatusIndicatorDelegate

- (void)messageStatusIndicatorDidTapRetry:(TJPMessageStatusIndicator *)sender {
    if (self.chatMessage && self.chatMessage.status == TJPChatMessageStatusFailed && [self.delegate respondsToSelector:@selector(chatMessageCell:didRequestRetryForMessage:)]) {
        [self.delegate chatMessageCell:self didRequestRetryForMessage:self.chatMessage];
    }
}


#pragma mark - Reuse
- (void)prepareForReuse {
    [super prepareForReuse];
    
    // 重置状态指示器
    self.statusIndicator.hidden = YES;
    [self.statusIndicator stopSendingAnimation];
    
    // 重置其他UI状态
    self.messageLabel.hidden = NO;
    self.messageImageView.hidden = YES;
    
    [[TJPMessageTimeoutManager sharedManager] removeMessageFromTimeoutCheck:self.chatMessage];

}

@end
