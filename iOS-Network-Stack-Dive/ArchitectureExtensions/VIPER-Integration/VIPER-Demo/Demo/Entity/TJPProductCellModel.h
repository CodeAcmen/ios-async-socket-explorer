//
//  TJPProductCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPProductCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *productId;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CGFloat price;
@property (nonatomic, assign) CGFloat originalPrice;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, assign) CGFloat rating;
@property (nonatomic, assign) NSInteger sales;
@property (nonatomic, strong) NSArray<NSString *> *tags;

@end

NS_ASSUME_NONNULL_END
