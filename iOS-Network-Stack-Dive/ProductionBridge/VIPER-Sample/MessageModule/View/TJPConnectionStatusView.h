//
//  TJPConnectionStatusView.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TJPConnectionStatus) {
    TJPConnectionStatusDisconnected,  // 断开连接
    TJPConnectionStatusConnecting,    // 连接中
    TJPConnectionStatusConnected,     // 已连接
    TJPConnectionStatusReconnecting   // 重连中
};

@interface TJPConnectionStatusView : UIView

@property (nonatomic, assign) TJPConnectionStatus status;
@property (nonatomic, assign) NSInteger messageCount;     // 消息计数
@property (nonatomic, assign) NSInteger pendingCount;     // 待发送消息数

- (void)updateStatus:(TJPConnectionStatus)status;
- (void)updateMessageCount:(NSInteger)count;
- (void)updatePendingCount:(NSInteger)count;

// 动画效果
- (void)startPulseAnimation;
- (void)stopPulseAnimation;


@end

NS_ASSUME_NONNULL_END
