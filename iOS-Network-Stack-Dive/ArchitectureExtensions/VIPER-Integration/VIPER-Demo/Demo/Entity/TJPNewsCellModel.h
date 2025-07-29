//
//  TJPNewsCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPNewsCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *newsId;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, copy) NSString *publishTime;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) NSInteger readCount;

@end

NS_ASSUME_NONNULL_END
