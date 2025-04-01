//
//  TJPToast.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@interface TJPToastLabel : UILabel
- (void)setMessageText:(NSString *)text;
@end


@interface TJPToast : NSObject

+ (instancetype)shareInstance;
+ (void)show:(NSString *)title duration:(CGFloat)duration;
+ (void)show:(NSString *)title duration:(CGFloat)duration controller:(UIViewController *)controller;


@end

NS_ASSUME_NONNULL_END
