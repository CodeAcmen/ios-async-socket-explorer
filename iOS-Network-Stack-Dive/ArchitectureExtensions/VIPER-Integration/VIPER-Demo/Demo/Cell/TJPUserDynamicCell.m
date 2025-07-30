//
//  TJPUserDynamicCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPUserDynamicCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

#import "TJPNineGridImageView.h"
#import "TJPLikeCommentAreaView.h"


@interface TJPUserDynamicCell ()

@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *userNameLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIView *actionView;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UIButton *commentButton;

// 九宫格图片
@property (nonatomic, strong) TJPNineGridImageView *nineGridView;
// 点赞评论区域
@property (nonatomic, strong) TJPLikeCommentAreaView *likeCommentArea;


@end

@implementation TJPUserDynamicCell
@synthesize cellModel = _cellModel;

- (void)dealloc {
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // 重置动态内容
    self.nineGridView.imageUrls = nil;
    self.likeCommentArea.hidden = YES;
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
    
    // 九宫格图片视图
    self.nineGridView = [[TJPNineGridImageView alloc] init];
    [self.contentView addSubview:self.nineGridView];
    
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
    
    // 点赞评论区域
    self.likeCommentArea = [[TJPLikeCommentAreaView alloc] init];
    [self.contentView addSubview:self.likeCommentArea];
    
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
        make.height.equalTo(@20);
    }];
    
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.userNameLabel);
        make.top.equalTo(self.userNameLabel.mas_bottom).offset(5);
        make.height.equalTo(@15);
    }];
    
    [self.contentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.userNameLabel);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.timeLabel.mas_bottom).offset(8);
    }];
    
    // 九宫格图片约束
    [self.nineGridView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        make.top.equalTo(self.contentLabel.mas_bottom).offset(8);
        make.width.lessThanOrEqualTo(@255); // 3 * 80 + 2 * 5 = 255
        make.height.equalTo(@0); // 默认高度0，动态设置
    }];
    
    [self.actionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contentLabel);
        make.top.equalTo(self.nineGridView.mas_bottom).offset(10);
        make.height.equalTo(@30);
    }];
    
    [self.commentButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.actionView);
        make.centerY.equalTo(self.actionView);
        make.width.equalTo(@60);
        make.height.equalTo(@30);
    }];
    
    [self.likeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.commentButton.mas_left).offset(-20);
        make.centerY.equalTo(self.actionView);
        make.width.equalTo(@60);
        make.height.equalTo(@30);
    }];
    
    // 点赞评论区域约束
    [self.likeCommentArea mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.actionView.mas_bottom).offset(8);
        make.height.equalTo(@0); // 默认高度0，动态设置
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];

    TJPUserDynamicCellModel *model = (TJPUserDynamicCellModel *)self.cellModel;
    
    // 设置基本信息
    self.userNameLabel.text = model.userName;
    self.timeLabel.text = model.publishTime;
    self.contentLabel.text = model.content;
    
    // 设置内容高度
    [self.contentLabel mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@([model calculateContentHeight]));
    }];
    
    [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:model.userAvatar]];
    [self.likeButton setTitle:[NSString stringWithFormat:@" %ld", model.likes] forState:UIControlStateNormal];
    [self.commentButton setTitle:[NSString stringWithFormat:@" %ld", model.comments] forState:UIControlStateNormal];
    
    // 配置九宫格图片
    self.nineGridView.imageUrls = model.images;
    CGFloat gridHeight = [model calculateNineGridHeight];
    [self.nineGridView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(gridHeight));
    }];
    self.nineGridView.hidden = (gridHeight == 0);
    
    // 配置点赞评论区域
    self.likeCommentArea.likeUsers = model.likeUsers;
    self.likeCommentArea.commentList = model.commentList;
    CGFloat likeCommentHeight = [model calculateLikeCommentAreaHeight];
    [self.likeCommentArea mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(likeCommentHeight));
    }];
    self.likeCommentArea.hidden = (likeCommentHeight == 0);

    
}

@end
