//
//  TJPConnectionStatusView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import "TJPConnectionStatusView.h"
#import <Masonry/Masonry.h>

@interface TJPConnectionStatusView ()

@property (nonatomic, strong) UIView *statusIndicator;          // 状态指示圆点
@property (nonatomic, strong) UILabel *statusLabel;             // 状态文字
@property (nonatomic, strong) UILabel *messageCountLabel;       // 消息计数
@property (nonatomic, strong) UIView *separatorLine;            // 分割线
@property (nonatomic, strong) UIStackView *contentStack;        // 内容容器

@property (nonatomic, strong) CAShapeLayer *pulseLayer;         // 脉搏动画层
@property (nonatomic, strong) NSTimer *reconnectTimer;          // 重连动画定时器


@end

@implementation TJPConnectionStatusView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
        [self setupConstraints];
        [self updateStatus:TJPConnectionStatusDisconnected];
    }
    return self;
}

- (void)dealloc {
    [self.reconnectTimer invalidate];
}


#pragma mark - UI Setup
- (void)setupUI {
    // 背景设置
    if (@available(iOS 13.0, *)) {
        self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.98 green:0.98 blue:0.98 alpha:1.0];
    }
    
    // 主要内容容器
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisHorizontal;
    self.contentStack.alignment = UIStackViewAlignmentCenter;
    self.contentStack.spacing = 8;
    [self addSubview:self.contentStack];
    
    // 状态指示器 - 圆点
    self.statusIndicator = [[UIView alloc] init];
    self.statusIndicator.layer.cornerRadius = 4;
    self.statusIndicator.backgroundColor = [UIColor systemGrayColor];
    [self.contentStack addArrangedSubview:self.statusIndicator];
    
    // 状态文字
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor labelColor];
    self.statusLabel.text = @"连接状态";
    [self.contentStack addArrangedSubview:self.statusLabel];
    
    // 弹性空间
    UIView *spacer = [[UIView alloc] init];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStack addArrangedSubview:spacer];
    
    // 消息计数标签
    self.messageCountLabel = [[UILabel alloc] init];
    self.messageCountLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.messageCountLabel.textColor = [UIColor secondaryLabelColor];
    self.messageCountLabel.text = @"0 条消息";
    [self.contentStack addArrangedSubview:self.messageCountLabel];
    
    // 底部分割线
    self.separatorLine = [[UIView alloc] init];
    self.separatorLine.backgroundColor = [[UIColor separatorColor] colorWithAlphaComponent:0.3];
    [self addSubview:self.separatorLine];
    
    // 设置脉搏动画层
    [self setupPulseLayer];
}

- (void)setupConstraints {
   // 主容器约束
   [self.contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
       make.leading.equalTo(self).offset(16);
       make.trailing.equalTo(self).offset(-16);
       make.centerY.equalTo(self);
   }];
   
   // 状态指示器约束
   [self.statusIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
       make.size.mas_equalTo(CGSizeMake(8, 8));
   }];
   
   // 分割线约束
   [self.separatorLine mas_makeConstraints:^(MASConstraintMaker *make) {
       make.leading.trailing.bottom.equalTo(self);
       make.height.mas_equalTo(0.5);
   }];
}

- (void)setupPulseLayer {
    self.pulseLayer = [CAShapeLayer layer];
    self.pulseLayer.frame = CGRectMake(0, 0, 16, 16);
    self.pulseLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 16, 16)].CGPath;
    self.pulseLayer.fillColor = [UIColor clearColor].CGColor;
    self.pulseLayer.strokeColor = [UIColor systemBlueColor].CGColor;
    self.pulseLayer.lineWidth = 1.0;
    self.pulseLayer.opacity = 0.8;
}

#pragma mark - Public Methods

- (void)updateStatus:(TJPConnectionStatus)status {
    _status = status;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self configureForStatus:status];
    } completion:^(BOOL finished) {
        [self handleStatusAnimations:status];
    }];
}

- (void)updateMessageCount:(NSInteger)count {
    _messageCount = count;
    
    NSString *text;
    if (count == 0) {
        text = @"暂无消息";
    } else if (count == 1) {
        text = @"1 条消息";
    } else {
        text = [NSString stringWithFormat:@"%ld 条消息", (long)count];
    }
    
    self.messageCountLabel.text = text;
    
    // 数字变化动画
//    [self animateCounterChange];
}

- (void)updatePendingCount:(NSInteger)count {
    _pendingCount = count;
    
    if (count > 0) {
        NSString *pendingText = [NSString stringWithFormat:@"(%ld 待发送)", (long)count];
        self.messageCountLabel.text = [self.messageCountLabel.text stringByAppendingString:pendingText];
        
        // 待发送消息有问题时，文字变红提醒
        self.messageCountLabel.textColor = [UIColor systemOrangeColor];
    }else {
        self.messageCountLabel.textColor = [UIColor secondaryLabelColor];
    }
}

- (void)startPulseAnimation {
    if (self.pulseLayer.superlayer) return;
    
    [self.statusIndicator.layer addSublayer:self.pulseLayer];
    self.pulseLayer.position = CGPointMake(4, 4);
    
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.5;
    scaleAnimation.toValue = @2.0;
    scaleAnimation.duration = 1.0;
    scaleAnimation.repeatCount = INFINITY;
    scaleAnimation.autoreverses = NO;
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.8;
    opacityAnimation.toValue = @0.0;
    opacityAnimation.duration = 1.0;
    opacityAnimation.repeatCount = INFINITY;
    opacityAnimation.autoreverses = NO;
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scaleAnimation, opacityAnimation];
    group.duration = 1.0;
    group.repeatCount = INFINITY;
    
    [self.pulseLayer addAnimation:group forKey:@"pulse"];
}

- (void)stopPulseAnimation {
    [self.pulseLayer removeAllAnimations];
    [self.pulseLayer removeFromSuperlayer];
}

#pragma mark - Private Methods

- (void)configureForStatus:(TJPConnectionStatus)status {
    switch (status) {
        case TJPConnectionStatusDisconnected:
            self.statusIndicator.backgroundColor = [UIColor systemRedColor];
            self.statusLabel.text = @"连接断开";
            self.statusLabel.textColor = [UIColor systemRedColor];
            break;
            
        case TJPConnectionStatusConnecting:
            self.statusIndicator.backgroundColor = [UIColor systemOrangeColor];
            self.statusLabel.text = @"连接中...";
            self.statusLabel.textColor = [UIColor systemOrangeColor];
            break;
            
        case TJPConnectionStatusConnected:
            self.statusIndicator.backgroundColor = [UIColor systemGreenColor];
            self.statusLabel.text = @"连接正常";
            self.statusLabel.textColor = [UIColor systemGreenColor];
            break;
            
        case TJPConnectionStatusReconnecting:
            self.statusIndicator.backgroundColor = [UIColor systemBlueColor];
            self.statusLabel.text = @"重连中...";
            self.statusLabel.textColor = [UIColor systemBlueColor];
            break;
    }
}

- (void)handleStatusAnimations:(TJPConnectionStatus)status {
    // 停止所有动画
    [self stopPulseAnimation];
    [self.reconnectTimer invalidate];
    
    switch (status) {
        case TJPConnectionStatusConnecting:
        case TJPConnectionStatusReconnecting:
            [self startPulseAnimation];
            [self startReconnectAnimation];
            break;
            
        case TJPConnectionStatusConnected:
            [self animateSuccessfulConnection];
            break;
            
        case TJPConnectionStatusDisconnected:
            [self animateDisconnection];
            break;
    }
}

- (void)startReconnectAnimation {
    // 文字闪烁效果
    self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(toggleTextOpacity) userInfo:nil repeats:YES];
}

- (void)toggleTextOpacity {
    [UIView animateWithDuration:0.3 animations:^{
        self.statusLabel.alpha = self.statusLabel.alpha > 0.5 ? 0.5 : 1.0;
    }];
}

- (void)animateSuccessfulConnection {
    // 成功连接的缩放动画
    self.statusLabel.alpha = 1.0;
    self.statusIndicator.transform = CGAffineTransformMakeScale(0.8, 0.8);
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:0 animations:^{
        self.statusIndicator.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)animateDisconnection {
    // 断开连接的摇摆动画
    self.statusLabel.alpha = 1.0;
    
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    shake.duration = 0.5;
    shake.values = @[@(-8), @(8), @(-6), @(6), @(-4), @(4), @(0)];
    
    [self.statusIndicator.layer addAnimation:shake forKey:@"shake"];
}

- (void)animateCounterChange {
    // 数字变化的缩放动画
    [UIView animateWithDuration:0.2 animations:^{
        self.messageCountLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            self.messageCountLabel.transform = CGAffineTransformIdentity;
        }];
    }];
}



@end
