//
//  UIColor+TJPColor.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/30.
//

#import "UIColor+TJPColor.h"

@implementation UIColor (TJPColor)

+ (UIColor *)tjp_White {
    return [UIColor whiteColor];
}

+ (UIColor *)tjp_tablebackColor {
    return [UIColor colorWithWhite:216.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_systemColor {
    return [UIColor colorWithRed:255.0f / 255.0f green:136.0f / 255.0f blue:102.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_blueColor {
    return [UIColor colorWithRed:0.0 green:148.0f / 255.0f blue:255.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_lightSystemColor {
    return [UIColor colorWithRed:255.0f / 255.0f green:134.0f / 255.0f blue:43.0f / 255.0f alpha:0.4f];
}

+ (UIColor *)tjp_backgroundGrayColor {
    return [UIColor tjp_colorWithHexString:@"#F2F2F2"];//245,245,245
}

+ (UIColor *)tjp_lightBackgroundGrayColor {
    return [UIColor tjp_colorWithHexString:@"#F7F8F9"];
}

/** 深黑背景*/
+ (UIColor *)tjp_darkBlackBackgroundGrayColor {
    return [UIColor tjp_colorWithHexString:@"#484848"];
}


+ (UIColor *)tjp_blackColor {
    return [UIColor colorWithWhite:51.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_lightBlackTextColor {
    return [UIColor colorWithWhite:34.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_lightTextColor {
    return [UIColor colorWithWhite:153.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_lightDarkTextColor {
    return [UIColor colorWithWhite:102.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_separateColor {
    return [UIColor colorWithWhite:222.0f / 255.0f alpha:1.0f];
}



+ (UIColor *)tjp_garyBorderLineColor {
    return [UIColor tjp_colorWithHexString:@"#F5F5F5"];
}

+ (UIColor *)tjp_lightGrayBorderColor {
    return [UIColor tjp_colorWithHexString:@"#CCCCCC"];
}

+ (UIColor *)tjp_coolGreyColor {
    return [UIColor colorWithRed:173.0f / 255.0f green:177.0f / 255.0f blue:191.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_slateGreyTextColor {
    return [UIColor colorWithRed:94.0f / 255.0f green:105.0f / 255.0f blue:119.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_paleOliveGreenColor {
    return [UIColor colorWithRed:152.0f / 255.0f green:211.0f / 255.0f blue:100.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_darkMintColor {
    return [UIColor colorWithRed:92.0f / 255.0f green:198.0f / 255.0f blue:91.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_saffronColor {
    return [UIColor colorWithRed:253.0f / 255.0f green:178.0f / 255.0f blue:9.0f / 255.0f alpha:1.0f];
}

+ (UIColor *)tjp_sandyBrownColor {
    return [UIColor colorWithRed:192.0f / 255.0f green:164.0f / 255.0f blue:108.0f / 255.0f alpha:1.0f];
}
+ (UIColor *)tjp_lightKhakiColor {
    return [UIColor colorWithRed:252.0f / 255.0f green:248.0f / 255.0f blue:238.0f / 255.0f alpha:1.0f];
}
+ (UIColor *)tjp_colorWithHexWithLong:(long)hexColor alpha:(CGFloat)a
{
    float red = ((float)((hexColor & 0xFF0000) >> 16))/255.0;
    float green = ((float)((hexColor & 0xFF00) >> 8))/255.0;
    float blue = ((float)(hexColor & 0xFF))/255.0;

    return [UIColor colorWithRed:red green:green blue:blue alpha:a];
}

+ (UIColor *)tjp_colorWithHexString:(NSString *)hexString {
    NSString *removeSharpMarkhexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    NSScanner *scanner = [NSScanner scannerWithString:removeSharpMarkhexString];
    unsigned result = 0;
    [scanner scanHexInt:&result];
    return [self tjp_colorWithHexWithLong:result alpha:1.0];
}


@end
