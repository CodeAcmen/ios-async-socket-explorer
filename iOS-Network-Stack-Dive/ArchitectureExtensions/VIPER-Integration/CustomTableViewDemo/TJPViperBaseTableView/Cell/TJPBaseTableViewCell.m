//
//  TJPBaseTableViewCell.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import "TJPBaseTableViewCell.h"
#import "TJPBaseCellModel.h"

#import <Masonry/Masonry.h>
#import "UIColor+TJPColor.h"


#pragma mark -
#pragma mark Constants
#pragma mark -
//**********************************************************************************************************
//
//    Constants
//
//**********************************************************************************************************

#pragma mark -
#pragma mark Private Interface
#pragma mark -
//**********************************************************************************************************
//
//    Private Interface
@interface TJPBaseTableViewCell () 

@end
//
//**********************************************************************************************************

@implementation TJPBaseTableViewCell
//@synthesize cellModel = _cellModel;
#pragma mark -
#pragma mark Object Constructors
//**************************************************
//    Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        [self initializationChildUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initializationChildUI];
    }
    return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(self) {
        [self initializationChildUI];
    }
    return self;
}

//**************************************************
#pragma mark -
#pragma mark ViewLifeCycle
//**************************************************
//    ViewLifeCycle Methods
//**************************************************
- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}


- (void)configureWithModel:(id<TJPBaseCellModelProtocol>)cellModel {
    if (self.cellModel == cellModel) {
        return;
    }
    self.cellModel = cellModel;
    if ([self.cellModel isKindOfClass:[TJPBaseCellModel class]]) {
        TJPBaseCellModel *cellViewModel = self.cellModel;
        
        self.tjp_bottomLineView.hidden = !cellViewModel.tjp_showBottomLine;
    }
}

- (void)cellWillDisplay:(id<TJPBaseCellModelProtocol>)cellModel {
    if (self.cellModel == cellModel) {
        return;
    }
    self.cellModel = cellModel;
}


#pragma mark -
#pragma mark Private Methods
//**************************************************
//    Private Methods
//**************************************************

- (void)initializationChildUI {
    // 子类可以覆盖这个方法进行UI初始化
    self.backgroundColor = [UIColor whiteColor];
}

#pragma mark -
#pragma mark Self Public Methods
//**************************************************
//    Self Public Methods
//**************************************************

#pragma mark -
#pragma mark HitTest
//**************************************************
//    HitTest Methods
//**************************************************

#pragma mark -
#pragma mark UserAction
//**************************************************
//    UserAction Methods
//**************************************************

#pragma mark -
#pragma mark Properties Getter & Setter
//**************************************************
//    Properties
- (UIView *)tjp_bottomLineView {
    if (!_tjp_bottomLineView) {
        _tjp_bottomLineView = [[UIView alloc] init];
        _tjp_bottomLineView.backgroundColor = [UIColor tjp_backgroundGrayColor];
        
        [self.contentView addSubview:_tjp_bottomLineView];
        [_tjp_bottomLineView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(15);
            make.right.mas_equalTo(-15);
            make.bottom.equalTo(self);
            make.height.mas_equalTo(0.5);
        }];
    }
    return _tjp_bottomLineView;
}

//**************************************************

@end
