//
//  TJPBaseTableViewLoadingProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//  加载动画协议,可注入 Lottie 动画、骨架屏、ProgressHUD 等

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPBaseTableViewLoadingProtocol <NSObject>

/// 返回一个 loading 状态的视图（供空态展示使用）
- (UIView *)customLoadingView;

@end

NS_ASSUME_NONNULL_END
