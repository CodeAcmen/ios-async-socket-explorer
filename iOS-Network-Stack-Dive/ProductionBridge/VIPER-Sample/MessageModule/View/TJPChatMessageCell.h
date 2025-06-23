//
//  TJPChatMessageCell.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class TJPChatMessage;

@interface TJPChatMessageCell : UITableViewCell

@property (nonatomic, strong) TJPChatMessage *chatMessage;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIImageView *messageImageView;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

- (void)configureWithMessage:(TJPChatMessage *)message;

+ (CGFloat)heightForMessage:(TJPChatMessage *)message inWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
