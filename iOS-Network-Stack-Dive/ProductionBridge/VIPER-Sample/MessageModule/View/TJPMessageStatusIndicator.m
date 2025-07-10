//
//  TJPMessageStatusIndicator.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/26.
//

#import "TJPMessageStatusIndicator.h"
#import <Masonry/Masonry.h>

@interface TJPMessageStatusIndicator ()
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;  // 转圈指示器
@property (nonatomic, strong) UIImageView *statusIcon;                    // 状态图标
@property (nonatomic, strong) UIButton *retryButton;                      // 重试按钮



@end

@implementation TJPMessageStatusIndicator



- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
        [self updateStatus:TJPMessageIndicatorStatusSending animated:NO];
    }
    return self;
}

+ (CGSize)indicatorSize {
    return CGSizeMake(20, 20);
}


- (void)setupUI {
    // 设置转圈指示器
    if (@available(iOS 13.0, *)) {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [UIColor systemBlueColor];
    [self addSubview:self.loadingIndicator];
    
    // 设置状态图标
    self.statusIcon = [[UIImageView alloc] init];
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIcon.alpha = 0.0;
    [self addSubview:self.statusIcon];
    
    // 设置重试按钮
    self.retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.retryButton.alpha = 0.0;
    [self.retryButton setImage:[UIImage imageNamed:@"img_msg_fail"] forState:UIControlStateNormal];
    [self.retryButton addTarget:self action:@selector(retryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.retryButton];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    // 转圈指示器约束
    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.centerY.equalTo(self);
        make.width.mas_equalTo(16);
        make.height.mas_equalTo(16);
    }];
    
    // 状态图标约束
    [self.statusIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.centerY.equalTo(self);
        make.width.mas_equalTo(16);
        make.height.mas_equalTo(16);
    }];

    // 重试按钮约束
    [self.retryButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.centerY.equalTo(self);
        make.width.mas_equalTo(20);
        make.height.mas_equalTo(20);
    }];
}

#pragma mark - Public Methods
- (void)updateStatus:(TJPMessageIndicatorStatus)status animated:(BOOL)animated {
    _status = status;
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            [self configureForStatus:status];
        }];
    } else {
        [self configureForStatus:status];
    }
}

- (void)startSendingAnimation {
    [self.loadingIndicator startAnimating];
}

- (void)stopSendingAnimation {
    [self.loadingIndicator stopAnimating];
}

#pragma mark - Private Methods
- (void)configureForStatus:(TJPMessageIndicatorStatus)status {
    // 重置所有视图的可见性
    [self.loadingIndicator stopAnimating];
    self.statusIcon.alpha = 0.0;
    self.retryButton.alpha = 0.0;
    
    switch (status) {
        case TJPMessageIndicatorStatusSending:
            [self configureSendingStatus];
            break;
            
        case TJPMessageIndicatorStatusSent:
            [self configureSentStatus];
            break;
            
        case TJPMessageIndicatorStatusFailed:
            [self configureFailedStatus];
            break;
            
        case TJPMessageIndicatorStatusRead:
            [self configureReadStatus];
            break;
    }
}

- (void)configureSendingStatus {
    [self.loadingIndicator startAnimating];
}

- (void)configureSentStatus {
    // 单勾号 - 发送成功
    self.statusIcon.image = [self createCheckmarkImage];
    self.statusIcon.tintColor = [UIColor systemBlueColor];
    self.statusIcon.alpha = 1.0;
    
    // 成功动画
    [self animateSuccessWithScale];
}

- (void)configureFailedStatus {
    // 重试按钮 图标为感叹号
//    self.statusIcon.image = [self createExclamationImage];
//    self.statusIcon.tintColor = [UIColor systemRedColor];
    self.statusIcon.alpha = 0.0;
    
    self.retryButton.alpha = 1.0;
    
    // 失败动画
//    [self animateFailureWithShake];
}

- (void)configureReadStatus {
    // 双勾号 - 已读
    self.statusIcon.image = [self createDoubleCheckmarkImage];
    self.statusIcon.tintColor = [UIColor systemBlueColor];
    self.statusIcon.alpha = 1.0;
}

#pragma mark - Icon Creation

- (UIImage *)createCheckmarkImage {
    // 创建单勾号图标
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(3, 8)];
    [path addLineToPoint:CGPointMake(6, 11)];
    [path addLineToPoint:CGPointMake(13, 4)];
    
    [[UIColor systemBlueColor] setStroke];
    path.lineWidth = 2.0;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [path stroke];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)createDoubleCheckmarkImage {
    // 创建双勾号图标
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 0);
    
    // 第一个勾号
    UIBezierPath *path1 = [UIBezierPath bezierPath];
    [path1 moveToPoint:CGPointMake(1, 8)];
    [path1 addLineToPoint:CGPointMake(4, 11)];
    [path1 addLineToPoint:CGPointMake(8, 7)];
    
    // 第二个勾号
    UIBezierPath *path2 = [UIBezierPath bezierPath];
    [path2 moveToPoint:CGPointMake(6, 8)];
    [path2 addLineToPoint:CGPointMake(9, 11)];
    [path2 addLineToPoint:CGPointMake(15, 5)];
    
    [[UIColor systemBlueColor] setStroke];
    path1.lineWidth = 2.0;
    path1.lineCapStyle = kCGLineCapRound;
    path1.lineJoinStyle = kCGLineJoinRound;
    [path1 stroke];
    
    path2.lineWidth = 2.0;
    path2.lineCapStyle = kCGLineCapRound;
    path2.lineJoinStyle = kCGLineJoinRound;
    [path2 stroke];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

//- (UIImage *)createExclamationImage {
//    // 创建感叹号图标
//    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 0);
//    
//    // 感叹号主体
//    UIBezierPath *path = [UIBezierPath bezierPath];
//    [path moveToPoint:CGPointMake(8, 3)];
//    [path addLineToPoint:CGPointMake(8, 10)];
//    
//    [[UIColor systemRedColor] setStroke];
//    path.lineWidth = 2.0;
//    path.lineCapStyle = kCGLineCapRound;
//    [path stroke];
//    
//    // 感叹号底部圆点
//    UIBezierPath *dotPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7, 12, 2, 2)];
//    [[UIColor systemRedColor] setFill];
//    [dotPath fill];
//    
//    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
//    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
//}

#pragma mark - Animations

- (void)animateSuccessWithScale {
    self.statusIcon.transform = CGAffineTransformMakeScale(0.5, 0.5);
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:0 animations:^{
        self.statusIcon.transform = CGAffineTransformIdentity;
    } completion:nil];
}

//- (void)animateFailureWithShake {
//    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
//    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//    shake.duration = 0.5;
//    shake.values = @[@(-4), @(4), @(-3), @(3), @(-2), @(2), @(0)];
//    
//    [self.statusIcon.layer addAnimation:shake forKey:@"shake"];
//}

#pragma mark - Actions

- (void)retryButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(messageStatusIndicatorDidTapRetry:)]) {
        [self.delegate messageStatusIndicatorDidTapRetry:self];
    }
}

@end
