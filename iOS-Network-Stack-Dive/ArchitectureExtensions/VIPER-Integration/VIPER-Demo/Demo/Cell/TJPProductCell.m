//
//  TJPProductCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPProductCell.h"
#import <Masonry/Masonry.h>

@interface TJPProductCell ()

@property (nonatomic, strong) UIImageView *productImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong) UIStackView *ratingStackView;
@property (nonatomic, strong) UILabel *salesLabel;
@property (nonatomic, strong) UIStackView *tagStackView;

@end

@implementation TJPProductCell
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
    
    // 商品图片
    self.productImageView = [[UIImageView alloc] init];
    self.productImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.productImageView.clipsToBounds = YES;
    self.productImageView.layer.cornerRadius = 8;
    self.productImageView.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.productImageView];
    
    // 商品名称
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
    self.nameLabel.textColor = [UIColor blackColor];
    self.nameLabel.numberOfLines = 2;
    [self.contentView addSubview:self.nameLabel];
    
    // 价格
    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.font = [UIFont boldSystemFontOfSize:18];
    self.priceLabel.textColor = [UIColor systemRedColor];
    [self.contentView addSubview:self.priceLabel];
    
    // 原价
    self.originalPriceLabel = [[UILabel alloc] init];
    self.originalPriceLabel.font = [UIFont systemFontOfSize:14];
    self.originalPriceLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.originalPriceLabel];
    
    // 评分视图
    self.ratingStackView = [[UIStackView alloc] init];
    self.ratingStackView.axis = UILayoutConstraintAxisHorizontal;
    self.ratingStackView.spacing = 2;
    [self.contentView addSubview:self.ratingStackView];
    
    // 销量
    self.salesLabel = [[UILabel alloc] init];
    self.salesLabel.font = [UIFont systemFontOfSize:12];
    self.salesLabel.textColor = [UIColor grayColor];
    [self.contentView addSubview:self.salesLabel];
    
    // 标签视图
    self.tagStackView = [[UIStackView alloc] init];
    self.tagStackView.axis = UILayoutConstraintAxisHorizontal;
    self.tagStackView.spacing = 4;
    [self.contentView addSubview:self.tagStackView];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.productImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(15);
        make.top.equalTo(self.contentView).offset(12);
        make.width.height.equalTo(@100);
    }];
    
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.productImageView.mas_right).offset(12);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.productImageView);
    }];
    
    [self.priceLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nameLabel);
        make.top.equalTo(self.nameLabel.mas_bottom).offset(8);
    }];
    
    [self.originalPriceLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.priceLabel.mas_right).offset(8);
        make.centerY.equalTo(self.priceLabel);
    }];
    
    [self.ratingStackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nameLabel);
        make.top.equalTo(self.priceLabel.mas_bottom).offset(8);
    }];
    
    [self.salesLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.ratingStackView.mas_right).offset(8);
        make.centerY.equalTo(self.ratingStackView);
    }];
    
    [self.tagStackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nameLabel);
        make.top.equalTo(self.ratingStackView.mas_bottom).offset(8);
        make.bottom.equalTo(self.contentView).offset(-12);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    
    self.nameLabel.text = self.cellModel.name;
    self.priceLabel.text = [NSString stringWithFormat:@"¥%.2f", self.cellModel.price];
    
    // 设置原价（删除线效果）
    NSString *originalPriceText = [NSString stringWithFormat:@"¥%.2f", self.cellModel.originalPrice];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:originalPriceText];
    [attributedString addAttribute:NSStrikethroughStyleAttributeName
                             value:@(NSUnderlineStyleSingle)
                             range:NSMakeRange(0, originalPriceText.length)];
    self.originalPriceLabel.attributedText = attributedString;
    
    self.salesLabel.text = [NSString stringWithFormat:@"已售%ld", self.cellModel.sales];
    
    // 设置评分星星
    [self setupRatingStars:self.cellModel.rating];
    
    // 设置标签
    [self setupTags:self.cellModel.tags];
    
    // 这里可以使用SDWebImage等库加载商品图片
    // [self.productImageView sd_setImageWithURL:[NSURL URLWithString:self.cellModel.imageUrl]];
}

- (void)setupRatingStars:(CGFloat)rating {
    // 清除之前的星星
    for (UIView *subview in self.ratingStackView.arrangedSubviews) {
        [self.ratingStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    // 添加星星
    for (int i = 0; i < 5; i++) {
        UIImageView *star = [[UIImageView alloc] init];
        star.contentMode = UIViewContentModeScaleAspectFit;
        [star mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.equalTo(@12);
        }];
        
        if (i < floor(rating)) {
            star.image = [UIImage systemImageNamed:@"star.fill"];
            star.tintColor = [UIColor systemYellowColor];
        } else if (i < rating) {
            star.image = [UIImage systemImageNamed:@"star.lefthalf.fill"];
            star.tintColor = [UIColor systemYellowColor];
        } else {
            star.image = [UIImage systemImageNamed:@"star"];
            star.tintColor = [UIColor lightGrayColor];
        }
        
        [self.ratingStackView addArrangedSubview:star];
    }
    
    // 添加评分数字
    UILabel *ratingLabel = [[UILabel alloc] init];
    ratingLabel.text = [NSString stringWithFormat:@"%.1f", rating];
    ratingLabel.font = [UIFont systemFontOfSize:12];
    ratingLabel.textColor = [UIColor grayColor];
    [self.ratingStackView addArrangedSubview:ratingLabel];
}

- (void)setupTags:(NSArray<NSString *> *)tags {
    // 清除之前的标签
    for (UIView *subview in self.tagStackView.arrangedSubviews) {
        [self.tagStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    // 添加标签
    for (NSString *tagText in tags) {
        UILabel *tagLabel = [[UILabel alloc] init];
        tagLabel.text = [NSString stringWithFormat:@" %@ ", tagText];
        tagLabel.font = [UIFont systemFontOfSize:10];
        tagLabel.textColor = [UIColor systemRedColor];
        tagLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.9 blue:0.9 alpha:1.0];
        tagLabel.layer.cornerRadius = 2;
        tagLabel.clipsToBounds = YES;
        tagLabel.textAlignment = NSTextAlignmentCenter;
        [self.tagStackView addArrangedSubview:tagLabel];
    }
}

@end
