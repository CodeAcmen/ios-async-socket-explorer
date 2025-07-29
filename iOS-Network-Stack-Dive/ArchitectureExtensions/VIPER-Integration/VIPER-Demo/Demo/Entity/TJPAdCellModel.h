//
//  TJPAdCellModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPAdCellModel : TJPBaseCellModel

@property (nonatomic, copy) NSString *adId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, copy) NSString *actionText;
@property (nonatomic, copy) NSString *actionUrl;

@end

NS_ASSUME_NONNULL_END
