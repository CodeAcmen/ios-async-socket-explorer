//
//  TJPUserDynamicCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPUserLikeModel, TJPUserComentModel;

@interface TJPUserDynamicCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userAvatar;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, strong) NSArray<NSString *> *images;
@property (nonatomic, copy) NSString *publishTime;
@property (nonatomic, assign) NSInteger likes;
@property (nonatomic, assign) NSInteger comments;


// 点赞用户列表
@property (nonatomic, strong) NSArray<TJPUserLikeModel *> *likeUsers;
// 评论列表
@property (nonatomic, strong) NSArray<TJPUserComentModel *> *commentList;

// 计算相关高度的方法
- (CGFloat)calculateContentHeight;
- (CGFloat)calculateNineGridHeight;
- (CGFloat)calculateLikeCommentAreaHeight;

@end

@interface TJPUserLikeModel : NSObject

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *userName;

@end

@interface TJPUserComentModel : NSObject

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *commentId;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *replyTo;


@end

NS_ASSUME_NONNULL_END
