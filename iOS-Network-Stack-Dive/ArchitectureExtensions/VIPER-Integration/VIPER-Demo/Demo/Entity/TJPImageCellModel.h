//
//  TJPImageCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPImageCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *imageId;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<NSString *> *imageUrls;
@property (nonatomic, assign) NSInteger likes;
@property (nonatomic, assign) NSInteger comments;
@property (nonatomic, copy) NSString *imageDescription;

@end

NS_ASSUME_NONNULL_END
