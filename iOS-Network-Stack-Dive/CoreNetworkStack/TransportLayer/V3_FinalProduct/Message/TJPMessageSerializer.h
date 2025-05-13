//
//  TJPMessageSerializer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  序列化工具

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageSerializer : NSObject

/// 文字序列化
+ (NSData *)serializeText:(NSString *)text tag:(uint16_t)tag;

/// 图片序列化
+ (NSData *)serializeImage:(UIImage *)image tag:(uint16_t)tag;


@end

NS_ASSUME_NONNULL_END
