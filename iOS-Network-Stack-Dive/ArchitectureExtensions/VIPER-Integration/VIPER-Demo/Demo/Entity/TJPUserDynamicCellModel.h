//
//  TJPUserDynamicCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPUserDynamicCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *userId;

@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userAvatar;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, strong) NSArray<NSString *> *images;
@property (nonatomic, copy) NSString *publishTime;
@property (nonatomic, assign) NSInteger likes;
@property (nonatomic, assign) NSInteger comments;

@end

NS_ASSUME_NONNULL_END
