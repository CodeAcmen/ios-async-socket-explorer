//
//  TJPAdCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPAdCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface TJPAdCell ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *adImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UILabel *adTagLabel;


// 翻转状态管理
@property (nonatomic, assign) BOOL isFlipped;
@property (nonatomic, strong) NSTimer *flipTimer;
@property (nonatomic, assign) BOOL hasFlipData;

@end
@implementation TJPAdCell
@synthesize cellModel = _cellModel;

- (void)prepareForReuse {
    [super prepareForReuse];
    [self stopAnimation];
    [self resetState];
    [self clearContent];
}

- (void)dealloc {
    [self stopAnimation];
}


- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}



- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
        [self resetState];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    // 容器视图
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor whiteColor];
    self.containerView.layer.cornerRadius = 8;
    self.containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 2);
    self.containerView.layer.shadowRadius = 4;
    self.containerView.layer.shadowOpacity = 0.1;
    [self.contentView addSubview:self.containerView];
    
    // 广告标识
    self.adTagLabel = [[UILabel alloc] init];
    self.adTagLabel.text = @"广告";
    self.adTagLabel.font = [UIFont systemFontOfSize:10];
    self.adTagLabel.textColor = [UIColor whiteColor];
    self.adTagLabel.backgroundColor = [UIColor systemBlueColor];
    self.adTagLabel.textAlignment = NSTextAlignmentCenter;
    self.adTagLabel.layer.cornerRadius = 2;
    self.adTagLabel.clipsToBounds = YES;
    [self.containerView addSubview:self.adTagLabel];
    
    // 广告图片
    self.adImageView = [[UIImageView alloc] init];
    self.adImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.adImageView.clipsToBounds = YES;
    self.adImageView.layer.cornerRadius = 6;
    self.adImageView.backgroundColor = [UIColor lightGrayColor];
    [self.containerView addSubview:self.adImageView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.numberOfLines = 1;
    [self.containerView addSubview:self.titleLabel];
    
    // 副标题
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textColor = [UIColor grayColor];
    self.subtitleLabel.numberOfLines = 1;
    [self.containerView addSubview:self.subtitleLabel];
    
    // 行动按钮
    self.actionButton = [[UIButton alloc] init];
    self.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.actionButton.backgroundColor = [UIColor systemBlueColor];
    self.actionButton.layer.cornerRadius = 15;
    [self.containerView addSubview:self.actionButton];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contentView).insets(UIEdgeInsetsMake(0, 15, 0, 15));
        make.top.bottom.equalTo(self.contentView).insets(UIEdgeInsetsMake(8, 0, 8, 0));
    }];
    
    [self.adTagLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.containerView).insets(UIEdgeInsetsMake(8, 8, 0, 0));
        make.width.equalTo(@30);
        make.height.equalTo(@16);
    }];
    
    [self.adImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.containerView).offset(12);
        make.top.equalTo(self.adTagLabel.mas_bottom).offset(8);
        make.bottom.equalTo(self.containerView).offset(-12);
        make.width.equalTo(@60);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.adImageView.mas_right).offset(12);
        make.top.equalTo(self.adImageView);
        make.right.lessThanOrEqualTo(self.actionButton.mas_left).offset(-8);
    }];
    
    [self.subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.titleLabel);
        make.top.equalTo(self.titleLabel.mas_bottom).offset(4);
    }];
    
    [self.actionButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.containerView).offset(-12);
        make.centerY.equalTo(self.containerView);
        make.width.equalTo(@80);
        make.height.equalTo(@30);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
        
    // 停止之前的动画
    [self stopAnimation];
    
    // 检查是否有翻转数据
    self.hasFlipData = [self checkFlipContentAvailable];
    
    // 显示原始内容
    [self showOriginalContent];
    
    // 开始动画（如果有翻转数据）
    if (self.hasFlipData) {
        NSLog(@"广告 '%@' 启用翻转动画", self.cellModel.title);
        [self startAnimationAfterDelay];
    } else {
        NSLog(@"广告 '%@' 无翻转内容，显示静态内容", self.cellModel.title);
    }
}


#pragma mark - Private Method
- (void)resetState {
   self.isFlipped = NO;
   self.hasFlipData = NO;
   self.cellModel = nil;
}

- (void)clearContent {
   self.titleLabel.text = nil;
   self.subtitleLabel.text = nil;
   [self.actionButton setTitle:nil forState:UIControlStateNormal];
   self.adImageView.image = nil;
   [self resetStyles];
}

- (void)resetStyles {
   self.actionButton.backgroundColor = [UIColor systemBlueColor];
   self.containerView.backgroundColor = [UIColor whiteColor];
   self.containerView.layer.borderWidth = 0;
}

- (BOOL)checkFlipContentAvailable {
    TJPAdFlipContentModel *flipContent = self.cellModel.flipContent;
    
    if (!flipContent) {
        return NO;
    }
    
    // 检查是否至少有一个有效的翻转内容
    BOOL hasValidContent = (flipContent.title && flipContent.title.length > 0) ||
                          (flipContent.subtitle && flipContent.subtitle.length > 0) ||
                          (flipContent.actionText && flipContent.actionText.length > 0) ||
                          (flipContent.imageUrl && flipContent.imageUrl.length > 0);
    
    NSLog(@"flipContent检查: title=%@, subtitle=%@, actionText=%@, imageUrl=%@", flipContent.title, flipContent.subtitle, flipContent.actionText, flipContent.imageUrl);
    
    return hasValidContent;
}

#pragma mark - 显示内容
- (void)showOriginalContent {
    self.titleLabel.text = self.cellModel.title;
    self.subtitleLabel.text = self.cellModel.subtitle;
    [self.actionButton setTitle:self.cellModel.actionText forState:UIControlStateNormal];
    
    if (self.cellModel.imageUrl && self.cellModel.imageUrl.length > 0) {
        [self.adImageView sd_setImageWithURL:[NSURL URLWithString:self.cellModel.imageUrl]];
    }
    
    [self resetStyles];
}

- (void)showFlippedContent {
    TJPAdFlipContentModel *flipContent = self.cellModel.flipContent;
    
    if (!flipContent) return;
    
    // 只更新有内容的字段，没有的保持原样
    if (flipContent.title && flipContent.title.length > 0) {
        self.titleLabel.text = flipContent.title;
    }
    
    if (flipContent.subtitle && flipContent.subtitle.length > 0) {
        self.subtitleLabel.text = flipContent.subtitle;
    }
    
    if (flipContent.actionText && flipContent.actionText.length > 0) {
        [self.actionButton setTitle:flipContent.actionText forState:UIControlStateNormal];
    }
    
    if (flipContent.imageUrl && flipContent.imageUrl.length > 0) {
        [self.adImageView sd_setImageWithURL:[NSURL URLWithString:flipContent.imageUrl]];
    }
    
    // 应用翻转样式
    [self applyFlippedStyles];
}

- (void)applyFlippedStyles {
    // 使用橙色作为翻转强调色
    UIColor *highlightColor = [UIColor systemOrangeColor];
    self.actionButton.backgroundColor = highlightColor;
    
    // 为容器添加轻微的强调色边框
    self.containerView.layer.borderWidth = 1.0;
    self.containerView.layer.borderColor = [highlightColor colorWithAlphaComponent:0.3].CGColor;
}

#pragma mark - 动画控制

- (void)startAnimationAfterDelay {
    // 延迟2秒开始，避免在滑动时启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 双重检查：确保cell还在屏幕上且有翻转数据
        if (self.window && self.hasFlipData && self.superview) {
            [self startAnimation];
        }
    });
}

- (void)startAnimation {
    [self stopAnimation]; // 防重复
    
    NSLog(@"开始翻转动画定时器");
    // 每4秒翻转一次
    self.flipTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(performFlip) userInfo:nil repeats:YES];

    // 立即执行第一次翻转
    [self performFlip];
}

- (void)stopAnimation {
    if (self.flipTimer) {
        [self.flipTimer invalidate];
        self.flipTimer = nil;
    }
}

- (void)performFlip {
    // 更严格的检查：确保cell真的还在屏幕上
    if (!self.window || !self.superview) {
        [self stopAnimation];
        return;
    }
    
    // 检查cell是否真正可见（在父视图的bounds内）
    if (![self isCellVisible]) {
        NSLog(@"Cell不可见 停止动画定时器");
        [self stopAnimation];
        return;
    }
    
    [UIView transitionWithView:self.containerView
                      duration:0.8
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction
                    animations:^{
        if (self.isFlipped) {
            [self showOriginalContent];
        } else {
            [self showFlippedContent];
        }
    } completion:^(BOOL finished) {
        if (finished) {
            self.isFlipped = !self.isFlipped;
        }
    }];
}

- (BOOL)isCellVisible {
    if (!self.superview) return NO;
    
    // 获取cell在superview中的frame
    CGRect cellFrame = [self.superview convertRect:self.frame toView:self.superview];
    CGRect superviewBounds = self.superview.bounds;
    
    // 检查是否有交集（即cell是否在可见区域内）
    return CGRectIntersectsRect(cellFrame, superviewBounds);
}


#pragma mark - Cell生命周期
- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    
    if (!newWindow) {
        // Cell即将离开window，立即停止动画
        [self stopAnimation];
    }
}

// 监听cell从父视图移除
- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    if (!newSuperview) {
        // Cell即将从父视图移除，立即停止动画
        [self stopAnimation];
    }
}

// 当cell的frame发生变化时也检查可见性
- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 如果有动画在运行，检查cell是否还可见
    if (self.flipTimer && ![self isCellVisible]) {
        [self stopAnimation];
    }
}


@end
