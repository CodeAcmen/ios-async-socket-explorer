//
//  TJPUserDynamicCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPUserDynamicCell.h"
#import <Masonry/Masonry.h>

@interface TJPUserDynamicCell ()

@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *userNameLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIStackView *imageStackView;
@property (nonatomic, strong) UIView *actionView;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UIButton *commentButton;

@end

@implementation TJPUserDynamicCell
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
    
    // 头像
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.layer.cornerRadius = 20;
    self.avatarImageView.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.avatarImageView];
    
    // 用户名
    self.userNameLabel = [[UILabel alloc] init];
    self.userNameLabel.font = [UIFont boldSystemFontOfSize:15];
    self.userNameLabel.textColor = [UIColor blackColor];
    [self.contentView addSubview:self.userNameLabel];
    
    // 时间
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [UIFont systemFontOfSize:12];
    self.timeLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.timeLabel];
    
    // 内容
    self.contentLabel = [[UILabel alloc] init];
    self.contentLabel.font = [UIFont systemFontOfSize:14];
    self.contentLabel.textColor = [UIColor darkGrayColor];
    self.contentLabel.numberOfLines = 0;
    [self.contentView addSubview:self.contentLabel];
    
    // 图片堆栈视图
    self.imageStackView = [[UIStackView alloc] init];
    self.imageStackView.axis = UILayoutConstraintAxisHorizontal;
    self.imageStackView.spacing = 8;
    [self.contentView addSubview:self.imageStackView];
    
    // 操作区域
    self.actionView = [[UIView alloc] init];
    [self.contentView addSubview:self.actionView];
    
    // 点赞按钮
    self.likeButton = [[UIButton alloc] init];
    [self.likeButton setImage:[UIImage systemImageNamed:@"heart"] forState:UIControlStateNormal];
    [self.likeButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    self.likeButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.actionView addSubview:self.likeButton];
    
    // 评论按钮
    self.commentButton = [[UIButton alloc] init];
    [self.commentButton setImage:[UIImage systemImageNamed:@"message"] forState:UIControlStateNormal];
    [self.commentButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    self.commentButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.actionView addSubview:self.commentButton];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.avatarImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(15);
        make.top.equalTo(self.contentView).offset(12);
        make.width.height.equalTo(@40);
    }];
    
    [self.userNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.avatarImageView.mas_right).offset(10);
        make.top.equalTo(self.avatarImageView);
        make.right.lessThanOrEqualTo(self.contentView).offset(-15);
    }];
    
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.userNameLabel);
        make.top.equalTo(self.userNameLabel.mas_bottom).offset(2);
    }];
    
    [self.contentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.userNameLabel);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.avatarImageView.mas_bottom).offset(12);
    }];
    
    [self.imageStackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        make.right.lessThanOrEqualTo(self.contentView).offset(-15);
        make.top.equalTo(self.contentLabel.mas_bottom).offset(8);
        make.height.equalTo(@80);
    }];
    
    [self.actionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contentLabel);
        make.top.equalTo(self.imageStackView.mas_bottom).offset(8);
        make.bottom.equalTo(self.contentView).offset(-12);
        make.height.equalTo(@30);
    }];
    
    [self.likeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.actionView);
        make.centerY.equalTo(self.actionView);
        make.width.equalTo(@60);
    }];
    
    [self.commentButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.likeButton.mas_right).offset(20);
        make.centerY.equalTo(self.actionView);
        make.width.equalTo(@60);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    
    self.userNameLabel.text = self.cellModel.userName;
    self.timeLabel.text =  self.cellModel.publishTime;
    self.contentLabel.text =  self.cellModel.content;
    
    [self.likeButton setTitle:[NSString stringWithFormat:@" %ld",  self.cellModel.likes] forState:UIControlStateNormal];
    [self.commentButton setTitle:[NSString stringWithFormat:@" %ld",  self.cellModel.comments] forState:UIControlStateNormal];
    
    // 清除之前的图片视图
    for (UIView *subview in self.imageStackView.arrangedSubviews) {
        [self.imageStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    // 添加新的图片视图
    for (NSString *imageUrl in  self.cellModel.images) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = 4;
        imageView.backgroundColor = [UIColor lightGrayColor];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@80);
        }];
        [self.imageStackView addArrangedSubview:imageView];
        
        // 这里可以使用SDWebImage等库加载图片
        // [imageView sd_setImageWithURL:[NSURL URLWithString:imageUrl]];
    }
    
    // 这里可以使用SDWebImage等库加载头像
    // [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString: self.cellModel.userAvatar]];
}

@end
