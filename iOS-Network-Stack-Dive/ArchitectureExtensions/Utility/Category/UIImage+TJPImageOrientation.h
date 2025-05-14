//
//  UIImage+TJPImageOrientation.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/14.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (TJPImageOrientation)

/// 修正图片方向（解决拍照图片旋转问题）
- (UIImage *)fixOrientation;


@end

NS_ASSUME_NONNULL_END
