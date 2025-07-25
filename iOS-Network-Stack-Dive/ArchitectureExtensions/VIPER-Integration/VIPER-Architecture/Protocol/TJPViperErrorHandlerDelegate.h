//
//  TJPViperErrorHandlerDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperErrorHandlerProtocol;

@protocol TJPViperErrorHandlerDelegate <NSObject>

@optional
/**
 * 询问是否应该处理外部错误
 * @param errorHandler 错误处理器
 * @param error 外部错误（如网络层错误）
 * @param context 上下文
 * @param completion 完成回调
 * @return YES表示已处理，NO表示使用默认处理
 */
- (BOOL)viperErrorHandler:(id<TJPViperErrorHandlerProtocol>)errorHandler shouldHandleExternalError:(NSError *)error inContext:(UIViewController *)context completion:(void(^)(BOOL shouldRetry))completion;

@end

NS_ASSUME_NONNULL_END
