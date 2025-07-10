//
//  TJPChatInputView.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class TJPChatInputView;

@protocol TJPChatInputViewDelegate <NSObject>

@required
- (void)chatInputView:(TJPChatInputView *)inputView didSendText:(NSString *)text;
- (void)chatInputViewDidTapImageButton:(TJPChatInputView *)inputView;

@optional
- (void)chatInputView:(TJPChatInputView *)inputView didChangeHeight:(CGFloat)height;
- (void)chatInputView:(TJPChatInputView *)inputView didChangeText:(NSString *)text;
- (void)chatInputViewDidBeginEditing:(TJPChatInputView *)inputView;
- (void)chatInputViewDidEndEditing:(TJPChatInputView *)inputView;

@end

@interface TJPChatInputView : UIView

@property (nonatomic, weak) id<TJPChatInputViewDelegate> delegate;


// 配置属性
@property (nonatomic, assign) CGFloat maxHeight;         // 最大高度，默认120
@property (nonatomic, assign) CGFloat minHeight;         // 最小高度，默认50
@property (nonatomic, assign) BOOL enabled;              // 是否启用，默认YES

@property (nonatomic, assign, readonly) CGFloat currentHeight;   // 当前高度
@property (nonatomic, assign, readonly) BOOL isEditing;          // 是否正在编辑

// 公开方法
- (void)setText:(NSString *)text;
- (NSString *)text;
- (void)clearText;
- (void)resignFirstResponder;
- (void)becomeFirstResponder;


@end

NS_ASSUME_NONNULL_END
