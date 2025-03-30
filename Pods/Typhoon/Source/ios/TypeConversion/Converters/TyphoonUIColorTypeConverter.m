////////////////////////////////////////////////////////////////////////////////
//
//  TYPHOON FRAMEWORK
//  Copyright 2013, Typhoon Framework Contributors
//  All Rights Reserved.
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////


#import "TyphoonUIColorTypeConverter.h"

#import "TyphoonColorConversionUtils.h"

#import <UIKit/UIKit.h>


@implementation TyphoonUIColorTypeConverter

- (id)supportedType
{
    return @"UIColor";
}

- (id)convert:(NSString *)stringValue
{
    stringValue = [TyphoonTypeConversionUtils textWithoutTypeFromTextValue:stringValue];
    
    struct RGBA color;
    
    if ([stringValue hasPrefix:@"#"] || [stringValue hasPrefix:@"0x"]) {
        color = [TyphoonColorConversionUtils colorFromHexString:stringValue];
    }
    else {
        color = [TyphoonColorConversionUtils colorFromCssStyleString:stringValue];
    }
    
    return [self colorFromRGBA:color];
}

- (UIColor *)colorFromRGBA:(struct RGBA)rgba
{
    return [UIColor colorWithRed:rgba.red green:rgba.green blue:rgba.blue alpha:rgba.alpha];
}

@end
