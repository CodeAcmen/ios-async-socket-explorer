//
//  TJPLikeCommentAreaView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/30.
//

#import "TJPLikeCommentAreaView.h"
#import <Masonry/Masonry.h>

@implementation TJPLikeCommentAreaView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    self.layer.cornerRadius = 4;
}

- (void)setLikeUsers:(NSArray<TJPUserLikeModel *> *)likeUsers {
    _likeUsers = likeUsers;
    [self updateLayout];
}

- (void)setCommentList:(NSArray<TJPUserComentModel *> *)commentList {
    _commentList = commentList;
    [self updateLayout];
}

- (void)updateLayout {
    // 清除所有子视图
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    
    if (self.likeUsers.count == 0 && self.commentList.count == 0) {
        return;
    }
    
    UIView *lastView = nil;
    CGFloat currentY = 8; // 顶部间距
    
    // 添加点赞区域
    if (self.likeUsers.count > 0) {
        UILabel *likeLabel = [self createLikeLabel];
        [self addSubview:likeLabel];
        
        [likeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self).insets(UIEdgeInsetsMake(0, 8, 0, 8));
            make.top.equalTo(self).offset(currentY);
            make.height.equalTo(@25);
        }];
        
        lastView = likeLabel;
        currentY += 25;
    }
    
    // 添加分割线
    if (self.likeUsers.count > 0 && self.commentList.count > 0) {
        UIView *separatorLine = [[UIView alloc] init];
        separatorLine.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        [self addSubview:separatorLine];
        
        [separatorLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self).insets(UIEdgeInsetsMake(0, 8, 0, 8));
            make.top.equalTo(lastView.mas_bottom).offset(5);
            make.height.equalTo(@0.5);
        }];
        
        lastView = separatorLine;
        currentY += 10; // 4 + 0.5 + 5.5
    }
    
    // 添加评论区域
    for (TJPUserComentModel *comment in self.commentList) {
        UILabel *commentLabel = [self createCommentLabel:comment];
        [self addSubview:commentLabel];
        
        [commentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self).insets(UIEdgeInsetsMake(0, 8, 0, 8));
            if (lastView) {
                make.top.equalTo(lastView.mas_bottom).offset(8);
            } else {
                make.top.equalTo(self).offset(currentY);
            }
        }];
        
        lastView = commentLabel;
        
        // 添加点击手势
        commentLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(commentTapped:)];
        [commentLabel addGestureRecognizer:tap];
    }
}

- (UILabel *)createLikeLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
    
    NSMutableString *likeText = [NSMutableString stringWithString:@"❤️ "];
    NSMutableArray *userNames = [NSMutableArray array];
    
    for (TJPUserLikeModel *user in self.likeUsers) {
        [userNames addObject:user.userName];
    }
    
    [likeText appendString:[userNames componentsJoinedByString:@"，"]];
    label.text = likeText;
    
    return label;
}

- (UILabel *)createCommentLabel:(TJPUserComentModel *)comment {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    
    NSString *userName = comment.userName;
    NSString *content = comment.content;
    NSString *replyTo = comment.replyTo;
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];
    
    // 用户名（蓝色）
    NSAttributedString *userNameAttr = [[NSAttributedString alloc]
                                       initWithString:userName
                                       attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0]}];
    [attributedText appendAttributedString:userNameAttr];
    
    // 回复标识
    if (replyTo.length > 0) {
        NSAttributedString *replyAttr = [[NSAttributedString alloc]
                                        initWithString:[NSString stringWithFormat:@" 回复 %@", replyTo]
                                        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0]}];
        [attributedText appendAttributedString:replyAttr];
    }
    
    // 评论内容
    NSAttributedString *contentAttr = [[NSAttributedString alloc]
                                      initWithString:[NSString stringWithFormat:@": %@", content]
                                      attributes:@{NSForegroundColorAttributeName: [UIColor darkGrayColor]}];
    [attributedText appendAttributedString:contentAttr];
    
    label.attributedText = attributedText;
    return label;
}

- (void)commentTapped:(UITapGestureRecognizer *)tap {
    NSLog(@"点击了评论区域");
    // 这里可以实现评论回复功能
}

@end
