//
//  TJPImageCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPImageCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>


@interface TJPImageCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *imageScrollView;
@property (nonatomic, strong) UIStackView *imageStackView;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UIButton *commentButton;

@end

@implementation TJPImageCell
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
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor blackColor];
    [self.contentView addSubview:self.titleLabel];
    
    // 图片滚动视图
    self.imageScrollView = [[UIScrollView alloc] init];
    self.imageScrollView.showsHorizontalScrollIndicator = NO;
    [self.contentView addSubview:self.imageScrollView];
    
    // 图片堆栈视图
    self.imageStackView = [[UIStackView alloc] init];
    self.imageStackView.axis = UILayoutConstraintAxisHorizontal;
    self.imageStackView.spacing = 8;
    [self.imageScrollView addSubview:self.imageStackView];
    
    // 描述
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.font = [UIFont systemFontOfSize:14];
    self.descriptionLabel.textColor = [UIColor darkGrayColor];
//    self.descriptionLabel.numberOfLines = 1;
    [self.contentView addSubview:self.descriptionLabel];
    
    // 点赞按钮
    self.likeButton = [[UIButton alloc] init];
    [self.likeButton setImage:[UIImage systemImageNamed:@"heart"] forState:UIControlStateNormal];
    [self.likeButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    self.likeButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.contentView addSubview:self.likeButton];
    
    // 评论按钮
    self.commentButton = [[UIButton alloc] init];
    [self.commentButton setImage:[UIImage systemImageNamed:@"message"] forState:UIControlStateNormal];
    [self.commentButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    self.commentButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.contentView addSubview:self.commentButton];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contentView).insets(UIEdgeInsetsMake(0, 15, 0, 15));
        make.top.equalTo(self.contentView).offset(12);
    }];
    
    [self.imageScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contentView);
        make.top.equalTo(self.titleLabel.mas_bottom).offset(8);
        make.height.equalTo(@180);
    }];
    
    [self.imageStackView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(self.imageScrollView);
        make.left.right.equalTo(self.imageScrollView).insets(UIEdgeInsetsMake(0, 15, 0, 15));
        make.height.equalTo(self.imageScrollView);
    }];
    
    [self.descriptionLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.titleLabel);
        make.top.equalTo(self.imageScrollView.mas_bottom).offset(8);
    }];
        
    [self.likeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLabel);
        make.top.equalTo(self.descriptionLabel.mas_bottom).offset(8);
        make.width.equalTo(@60);
    }];
    
    [self.commentButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.likeButton.mas_right).offset(20);
        make.centerY.equalTo(self.likeButton);
        make.width.equalTo(@60);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    
    self.titleLabel.text = self.cellModel.title;
    self.descriptionLabel.text = self.cellModel.imageDescription;
    
    [self.likeButton setTitle:[NSString stringWithFormat:@" %ld", self.cellModel.likes] forState:UIControlStateNormal];
    [self.commentButton setTitle:[NSString stringWithFormat:@" %ld", self.cellModel.comments] forState:UIControlStateNormal];
    
    // 清除之前的图片视图
    for (UIView *subview in self.imageStackView.arrangedSubviews) {
        [self.imageStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    // 添加新的图片视图
    for (NSString *imageUrl in self.cellModel.imageUrls) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = 4;
        imageView.backgroundColor = [UIColor lightGrayColor];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@150);
        }];
        [self.imageStackView addArrangedSubview:imageView];
        
         [imageView sd_setImageWithURL:[NSURL URLWithString:imageUrl]];
    }
}

@end
