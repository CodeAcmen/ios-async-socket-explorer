//
//  TJPViperErrorHandlerProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
//  应用层错误处理器协议

#import <UIKit/UIKit.h>
#import "TJPViperErrorDefine.h"

NS_ASSUME_NONNULL_BEGIN
@protocol TJPViperErrorHandlerDelegate;

@protocol TJPViperErrorHandlerProtocol <NSObject>

/// 委托对象，用于处理外部错误
@property (nonatomic, weak) id<TJPViperErrorHandlerDelegate> delegate;

/**
 * 处理错误（仅处理应用层错误，外部错误委托给delegate）
 * @param error 错误对象
 * @param context 上下文视图控制器
 * @param completion 完成回调
 */
- (void)handleError:(NSError *)error inContext:(UIViewController *)context completion:(void(^)(BOOL shouldRetry))completion;

/**
 * 创建应用层错误
 */
- (NSError *)createViperErrorWithCode:(TJPViperError)errorCode description:(nullable NSString *)description;

/**
 * 重置错误状态
 */
- (void)resetErrorState;

@end

NS_ASSUME_NONNULL_END
