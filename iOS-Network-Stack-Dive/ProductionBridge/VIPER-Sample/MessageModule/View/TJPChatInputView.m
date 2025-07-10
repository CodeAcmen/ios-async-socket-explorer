//
//  TJPChatInputView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/25.
//

#import "TJPChatInputView.h"
#import <Masonry/Masonry.h>

@interface TJPChatInputView () <UITextViewDelegate>

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIButton *imageButton;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIView *separatorLine;


@property (nonatomic, assign) CGFloat currentHeight;

@end


@implementation TJPChatInputView

#pragma mark - Initialization
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupDefaultValues];
        [self setupUI];
        [self setupConstraints];
//        [self registerNotifications];
    }
    return self;
}


- (void)dealloc {
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UI
- (void)setupDefaultValues {
    _maxHeight = 120.0;
    _minHeight = 52.0;
    _enabled = YES;
    _currentHeight = _minHeight;
}


- (void)setupUI {
    self.backgroundColor = [UIColor systemGray6Color];
    
    // 分割线
    self.separatorLine = [[UIView alloc] init];
    self.separatorLine.backgroundColor = [[UIColor separatorColor] colorWithAlphaComponent:0.3];
    [self addSubview:self.separatorLine];
    
    // 容器视图
    self.containerView = [[UIView alloc] init];
    [self addSubview:self.containerView];
    
    // 图片按钮
    self.imageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.imageButton setImage:[UIImage imageNamed:@"img_chat_bar_camera"] forState:UIControlStateNormal];
    self.imageButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.imageButton addTarget:self action:@selector(imageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.imageButton];
    
    // 文本输入框
    self.textView = [[UITextView alloc] init];
    self.textView.delegate = self;
    self.textView.font = [UIFont systemFontOfSize:16];
    self.textView.layer.cornerRadius = 6;
    self.textView.layer.borderWidth = 0;
//    self.textView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.textView.backgroundColor = [UIColor whiteColor];
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 12, 8, 12);
    self.textView.scrollIndicatorInsets = self.textView.textContainerInset;
    self.textView.returnKeyType = UIReturnKeySend;
    self.textView.enablesReturnKeyAutomatically = YES;
    self.textView.showsVerticalScrollIndicator = NO;
    [self.containerView addSubview:self.textView];
    
    // 发送按钮
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor systemGray3Color] forState:UIControlStateDisabled];
    self.sendButton.layer.cornerRadius = 8;
    self.sendButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    self.sendButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self.sendButton addTarget:self action:@selector(sendButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.sendButton];
    
    [self updateSendButtonState];
}

- (void)setupConstraints {
    // 分割线
    [self.separatorLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.equalTo(self);
        make.height.mas_equalTo(0.5);
    }];
    
    // 容器视图
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.separatorLine.mas_bottom).offset(8);
        make.leading.equalTo(self).offset(12);
        make.trailing.equalTo(self).offset(-12);
        make.bottom.equalTo(self).offset(-8);
    }];
    
    // 图片按钮
    [self.imageButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self.containerView);
        make.bottom.equalTo(self.containerView).offset(-2);
        make.size.mas_equalTo(CGSizeMake(36, 36));
    }];
    
    // 发送按钮
    [self.sendButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.trailing.equalTo(self.containerView);
        make.bottom.equalTo(self.containerView).offset(-2);
        make.size.mas_equalTo(CGSizeMake(58, 32));
    }];
    
    // 文本输入框 - 关键修复：给一个最小高度约束
    [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self.imageButton.mas_trailing).offset(10);
        make.trailing.equalTo(self.sendButton.mas_leading).offset(-10);
        make.top.bottom.equalTo(self.containerView);
        make.height.mas_greaterThanOrEqualTo(36).priorityMedium();  
    }];
}


#pragma mark - Actions
- (void)imageButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(chatInputViewDidTapImageButton:)]) {
        [self.delegate chatInputViewDidTapImageButton:self];
    }
}

- (void)sendButtonTapped:(UIButton *)sender {
    [self sendCurrentText];
}

- (void)sendCurrentText {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (text.length > 0) {
        if ([self.delegate respondsToSelector:@selector(chatInputView:didSendText:)]) {
            [self.delegate chatInputView:self didSendText:text];
        }
        [self clearText];
    }
}

#pragma mark - Public Methods
- (void)setText:(NSString *)text {
    self.textView.text = text ?: @"";
    [self textViewDidChange:self.textView];
}

- (NSString *)text {
    return self.textView.text ?: @"";
}

- (void)clearText {
    [self setText:@""];
}

- (void)resignFirstResponder {
    [self.textView resignFirstResponder];
}

- (void)becomeFirstResponder {
    [self.textView becomeFirstResponder];
}

- (BOOL)isEditing {
    return self.textView.isFirstResponder;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    self.textView.editable = enabled;
    self.imageButton.enabled = enabled;
    [self updateSendButtonState];
}


#pragma mark - Private Methods
- (void)updateSendButtonState {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasText = text.length > 0;
    
    self.sendButton.enabled = self.enabled && hasText;
    self.sendButton.backgroundColor = (self.sendButton.enabled) ? [UIColor systemBlueColor] : [UIColor colorWithWhite:0 alpha:0.2];
}

- (void)updateHeightWithTextView:(UITextView *)textView {
    // 计算文本需要的高度
    CGSize textSize = [textView sizeThatFits:CGSizeMake(textView.frame.size.width, CGFLOAT_MAX)];
    CGFloat textHeight = textSize.height;
    
    // 计算新的容器高度
    textHeight = MAX(36, textHeight);
    
    // 计算整个输入框需要的总高度：分割线0.5 + 上边距8 + 文本高度 + 下边距8
    CGFloat newTotalHeight = 0.5 + 8 + textHeight + 8;

    // 限制在最小和最大高度之间
    newTotalHeight = MAX(self.minHeight, MIN(self.maxHeight, newTotalHeight));
    
    if (fabs(newTotalHeight - self.currentHeight) > 1.0) {
        _currentHeight = newTotalHeight;
        
        // 通知代理高度变化
        if ([self.delegate respondsToSelector:@selector(chatInputView:didChangeHeight:)]) {
            [self.delegate chatInputView:self didChangeHeight:newTotalHeight];
        }
    }
    
    // 启用或禁用滚动
    CGFloat maxTextHeight = self.maxHeight - 16.5; // 减去分割线和边距
    textView.scrollEnabled = (textHeight > maxTextHeight);
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([self.delegate respondsToSelector:@selector(chatInputViewDidBeginEditing:)]) {
        [self.delegate chatInputViewDidBeginEditing:self];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if ([self.delegate respondsToSelector:@selector(chatInputViewDidEndEditing:)]) {
        [self.delegate chatInputViewDidEndEditing:self];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateSendButtonState];
    [self updateHeightWithTextView:textView];
    
    if ([self.delegate respondsToSelector:@selector(chatInputView:didChangeText:)]) {
        [self.delegate chatInputView:self didChangeText:textView.text];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // 处理发送按钮逻辑
    if ([text isEqualToString:@"\n"]) {
        [self sendCurrentText];
        return NO;
    }
    
    return YES;
}

@end
