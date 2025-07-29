//
//  TJPVideoCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPVideoCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *videoId;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *coverUrl;
@property (nonatomic, copy) NSString *videoUrl;
@property (nonatomic, copy) NSString *duration;
@property (nonatomic, assign) NSInteger playCount;
@property (nonatomic, copy) NSString *author;

@end

NS_ASSUME_NONNULL_END
