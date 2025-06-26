//
//  TJPMessageStatusIndicator.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TJPMessageIndicatorStatus) {
    TJPMessageIndicatorStatusSending,    // 发送中（转圈）
    TJPMessageIndicatorStatusSent,       // 发送成功（勾号）
    TJPMessageIndicatorStatusFailed,     // 发送失败（感叹号）
    TJPMessageIndicatorStatusRead        // 已读（双勾号）
};

@protocol TJPMessageStatusIndicatorDelegate <NSObject>
@optional
- (void)messageStatusIndicatorDidTapRetry:(id)sender;
@end

@interface TJPMessageStatusIndicator : UIView

@property (nonatomic, weak) id<TJPMessageStatusIndicatorDelegate> delegate;
@property (nonatomic, assign) TJPMessageIndicatorStatus status;

// 用于重试时识别消息
@property (nonatomic, strong) NSString *messageId;

- (void)updateStatus:(TJPMessageIndicatorStatus)status animated:(BOOL)animated;
- (void)startSendingAnimation;
- (void)stopSendingAnimation;

// 便捷方法
+ (CGSize)indicatorSize;


@end

NS_ASSUME_NONNULL_END
