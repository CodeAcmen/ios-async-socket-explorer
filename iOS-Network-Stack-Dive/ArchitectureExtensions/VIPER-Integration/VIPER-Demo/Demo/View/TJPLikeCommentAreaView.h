//
//  TJPLikeCommentAreaView.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/30.
//

#import <UIKit/UIKit.h>
#import "TJPUserDynamicCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPLikeCommentAreaView : UIView

@property (nonatomic, strong) NSArray<TJPUserLikeModel *> *likeUsers;
@property (nonatomic, strong) NSArray<TJPUserComentModel *> *commentList;



@end

NS_ASSUME_NONNULL_END
