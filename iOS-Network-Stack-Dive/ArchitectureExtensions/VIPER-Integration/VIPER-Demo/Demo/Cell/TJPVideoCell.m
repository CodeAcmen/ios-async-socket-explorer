//
//  TJPVideoCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPVideoCell.h"
#import <Masonry/Masonry.h>


@interface TJPVideoCell ()

@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *playCountLabel;

@end

@implementation TJPVideoCell
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
    
    // 封面图片
    self.coverImageView = [[UIImageView alloc] init];
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.clipsToBounds = YES;
    self.coverImageView.layer.cornerRadius = 8;
    self.coverImageView.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.coverImageView];
    
    // 播放按钮
    self.playButton = [[UIButton alloc] init];
    [self.playButton setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
    self.playButton.tintColor = [UIColor whiteColor];
    [self.contentView addSubview:self.playButton];
    
    // 时长标签
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    self.durationLabel.textAlignment = NSTextAlignmentCenter;
    self.durationLabel.layer.cornerRadius = 4;
    self.durationLabel.clipsToBounds = YES;
    [self.contentView addSubview:self.durationLabel];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.numberOfLines = 2;
    [self.contentView addSubview:self.titleLabel];
    
    // 作者
    self.authorLabel = [[UILabel alloc] init];
    self.authorLabel.font = [UIFont systemFontOfSize:14];
    self.authorLabel.textColor = [UIColor grayColor];
    [self.contentView addSubview:self.authorLabel];
    
    // 播放数
    self.playCountLabel = [[UILabel alloc] init];
    self.playCountLabel.font = [UIFont systemFontOfSize:12];
    self.playCountLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.playCountLabel];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(15);
        make.top.equalTo(self.contentView).offset(12);
        make.width.equalTo(@120);
        make.height.equalTo(@90);
    }];
    
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.coverImageView);
        make.width.height.equalTo(@40);
    }];
    
    [self.durationLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.coverImageView).offset(-8);
        make.bottom.equalTo(self.coverImageView).offset(-8);
        make.height.equalTo(@20);
        make.width.greaterThanOrEqualTo(@40);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coverImageView.mas_right).offset(12);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.coverImageView);
    }];
    
    [self.authorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.titleLabel);
        make.top.equalTo(self.titleLabel.mas_bottom).offset(8);
    }];
    
    [self.playCountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLabel);
        make.bottom.equalTo(self.coverImageView);
        make.bottom.equalTo(self.contentView).offset(-12);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    
    self.titleLabel.text = self.cellModel.title;
    self.authorLabel.text = self.cellModel.author;
    self.durationLabel.text = [NSString stringWithFormat:@" %@ ", self.cellModel.duration];
    self.playCountLabel.text = [NSString stringWithFormat:@"%ld次播放", self.cellModel.playCount];
    
    // 这里可以使用SDWebImage等库加载封面图片
    // [self.coverImageView sd_setImageWithURL:[NSURL URLWithString:self.cellModel.coverUrl]];
}

@end
