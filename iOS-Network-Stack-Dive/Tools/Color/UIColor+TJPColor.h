//
//  UIColor+TJPColor.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (TJPColor)

+ (UIColor *)tjp_White;

+ (UIColor *)tjp_tablebackColor ;

+ (UIColor *)tjp_systemColor ;

+ (UIColor *)tjp_lightSystemColor;

+ (UIColor *)tjp_blueColor ;
/** 背景色*/
+ (UIColor *)tjp_backgroundGrayColor;
/** 浅色背景*/
+ (UIColor *)tjp_lightBackgroundGrayColor;
/** 深黑背景*/
+ (UIColor *)tjp_darkBlackBackgroundGrayColor;


/** 用于重要标题*/
+ (UIColor *)tjp_blackColor ;

+ (UIColor *)tjp_lightBlackTextColor;
/** 用于辅助、次要信息内容*/
+ (UIColor *)tjp_lightTextColor;
/** 用于基本信息内容*/
+ (UIColor *)tjp_lightDarkTextColor;
/** 用于分割*/
+ (UIColor *)tjp_separateColor;


+ (UIColor *)tjp_garyBorderLineColor;

+ (UIColor *)tjp_lightGrayBorderColor;

+ (UIColor *)tjp_coolGreyColor;

+ (UIColor *)tjp_slateGreyTextColor;

+ (UIColor *)tjp_paleOliveGreenColor;

+ (UIColor *)tjp_darkMintColor;

+ (UIColor *)tjp_saffronColor;

+ (UIColor *)tjp_sandyBrownColor;

+ (UIColor *)tjp_lightKhakiColor;

+ (UIColor *)tjp_colorWithHexString:(NSString *)hexString;

@end

NS_ASSUME_NONNULL_END
