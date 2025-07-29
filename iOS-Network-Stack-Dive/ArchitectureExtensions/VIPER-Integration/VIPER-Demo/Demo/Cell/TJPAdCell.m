//
//  TJPAdCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPAdCell.h"
#import <Masonry/Masonry.h>

@interface TJPAdCell ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *adImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UILabel *adTagLabel;

@end
@implementation TJPAdCell
@synthesize cellModel = _cellModel;

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
    
    self.titleLabel.text = self.cellModel.title;
    self.subtitleLabel.text = self.cellModel.subtitle;
    [self.actionButton setTitle:self.cellModel.actionText forState:UIControlStateNormal];
    
    // 这里可以使用SDWebImage等库加载广告图片
    // [self.adImageView sd_setImageWithURL:[NSURL URLWithString:self.cellModel.imageUrl]];
}

@end
