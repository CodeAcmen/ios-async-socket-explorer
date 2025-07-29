//
//  TJPNewsCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPNewsCell.h"
#import <Masonry/Masonry.h>

@interface TJPNewsCell ()

@property (nonatomic, strong) UIImageView *newsImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *sourceLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *readCountLabel;

@end

@implementation TJPNewsCell
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
    
    // 新闻图片
    self.newsImageView = [[UIImageView alloc] init];
    self.newsImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.newsImageView.clipsToBounds = YES;
    self.newsImageView.layer.cornerRadius = 4;
    self.newsImageView.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.newsImageView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.numberOfLines = 2;
    [self.contentView addSubview:self.titleLabel];
    
    // 摘要
    self.summaryLabel = [[UILabel alloc] init];
    self.summaryLabel.font = [UIFont systemFontOfSize:14];
    self.summaryLabel.textColor = [UIColor grayColor];
    self.summaryLabel.numberOfLines = 2;
    [self.contentView addSubview:self.summaryLabel];
    
    // 来源
    self.sourceLabel = [[UILabel alloc] init];
    self.sourceLabel.font = [UIFont systemFontOfSize:12];
    self.sourceLabel.textColor = [UIColor systemBlueColor];
    [self.contentView addSubview:self.sourceLabel];
    
    // 时间
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [UIFont systemFontOfSize:12];
    self.timeLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.timeLabel];
    
    // 阅读数
    self.readCountLabel = [[UILabel alloc] init];
    self.readCountLabel.font = [UIFont systemFontOfSize:12];
    self.readCountLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.readCountLabel];
    
    [self setupConstraints];
}

- (void)setupConstraints {
    [self.newsImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(15);
        make.top.equalTo(self.contentView).offset(12);
        make.width.height.equalTo(@80);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.newsImageView.mas_right).offset(12);
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(self.newsImageView);
    }];
    
    [self.summaryLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.titleLabel);
        make.top.equalTo(self.titleLabel.mas_bottom).offset(8);
    }];
    
    [self.sourceLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLabel);
        make.bottom.equalTo(self.newsImageView);
    }];
    
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.sourceLabel.mas_right).offset(10);
        make.centerY.equalTo(self.sourceLabel);
    }];
    
    [self.readCountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.titleLabel);
        make.centerY.equalTo(self.sourceLabel);
    }];
}

- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    [super configureWithModel:cellModel];
    
    self.titleLabel.text = self.cellModel.title;
    self.summaryLabel.text = self.cellModel.summary;
    self.sourceLabel.text = self.cellModel.source;
    self.timeLabel.text = self.cellModel.publishTime;
    self.readCountLabel.text = [NSString stringWithFormat:@"%ld阅读", self.cellModel.readCount];
    
//     [self.newsImageView sd_setImageWithURL:[NSURL URLWithString:self.cellModel.imageUrl]];
}

@end
