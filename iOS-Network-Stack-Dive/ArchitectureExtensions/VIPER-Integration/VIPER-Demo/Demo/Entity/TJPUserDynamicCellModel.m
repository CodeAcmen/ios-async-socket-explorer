//
//  TJPUserDynamicCellModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPUserDynamicCellModel.h"
#import <YYModel/YYModel.h>

@implementation TJPUserDynamicCellModel

- (NSString *)cellName {
    return @"TJPUserDynamicCell";
}


+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{
        @"likeUsers" : [TJPUserLikeModel class],
        @"commentList" : [TJPUserComentModel class]
    };
}

- (CGFloat)calculateCellHeight {
    CGFloat totalHeight = 0;
    
    // 顶部头像区域：top(12) + avatar(40)
    totalHeight += 12 + 40;
    
    // 用户名区域：userNameLabel + timeLabel + 间距
    totalHeight += 5; // userNameLabel 到 timeLabel 的间距
    
    // 内容文本高度：timeLabel 到 contentLabel 的间距(8) + 内容高度
    totalHeight += 8 + [self calculateContentHeight];
    
    // 图片区域
    CGFloat gridHeight = [self calculateNineGridHeight];
    if (gridHeight > 0) {
        totalHeight += gridHeight + 10; // 图片高度 + 下间距
    }
    
    // actionView 区域：height(30) + space(8)
    totalHeight += 30 + 8;
    
    // 点赞评论区域
    CGFloat likeCommentHeight = [self calculateLikeCommentAreaHeight];
    if (likeCommentHeight > 0) {
        totalHeight += likeCommentHeight + 12; // 点赞评论高度 + 底部间距
    } else {
        totalHeight += 12; // 只有底部间距
    }
    
    return totalHeight;
}

- (CGFloat)calculateContentHeight {
    if (self.content.length == 0) {
        return 0;
    }
    
    // 计算 contentLabel 的可用宽度
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat leftMargin = 15;  // contentView 左边距
    CGFloat avatarWidth = 40; // 头像宽度
    CGFloat avatarToContent = 10; // 头像到内容的间距
    CGFloat rightMargin = 15; // contentView 右边距
    
    CGFloat contentWidth = screenWidth - leftMargin - avatarWidth - avatarToContent - rightMargin;
    
    // 计算文本高度
    CGRect textRect = [self.content boundingRectWithSize:CGSizeMake(contentWidth, MAXFLOAT)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}
                                                 context:nil];
    
    return ceil(textRect.size.height);
}

- (CGFloat)calculateNineGridHeight {
    if (self.images.count == 0) return 0;
    
    CGFloat itemWidth = 80;
    CGFloat itemSpacing = 5;
    NSInteger rows = (self.images.count - 1) / 3 + 1; // 计算行数
    
    return rows * itemWidth + (rows - 1) * itemSpacing;
}

- (CGFloat)calculateLikeCommentAreaHeight {
    if (self.likeUsers.count == 0 && self.commentList.count == 0) {
        return 0;
    }
    
    CGFloat height = 16; // 上下内边距 8 + 8
    
    // 点赞区域高度
    if (self.likeUsers.count > 0) {
        height += 25; // 点赞行高度
    }
    
    // 分割线高度
    if (self.likeUsers.count > 0 && self.commentList.count > 0) {
        height += 8; // 分割线区域
    }
    
    // 评论区域高度 - 需要计算每条评论的实际高度
    for (TJPUserComentModel *comment in self.commentList) {
        height += [self calculateCommentHeight:comment];
    }
    
    return height;
}

- (CGFloat)calculateCommentHeight:(TJPUserComentModel *)comment {
    // 构建完整的评论文本
    NSMutableString *fullText = [NSMutableString string];
    [fullText appendString:comment.userName];
    
    if (comment.replyTo.length > 0) {
        [fullText appendFormat:@" 回复 %@", comment.replyTo];
    }
    
    [fullText appendFormat:@": %@", comment.content];
    
    // 计算文本高度
    CGFloat commentWidth = [UIScreen mainScreen].bounds.size.width - 15 - 40 - 10 - 15 - 16; // 减去点赞评论区域的内边距
    
    CGRect textRect = [fullText boundingRectWithSize:CGSizeMake(commentWidth, MAXFLOAT)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13]}
                                             context:nil];
    
    return MAX(ceil(textRect.size.height) + 8, 22); // 最小高度22，包含上下间距
}

@end


@implementation TJPUserLikeModel



@end

@implementation TJPUserComentModel



@end
