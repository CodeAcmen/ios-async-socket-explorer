//
//  TJPMessageSerializer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  序列化工具

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageSerializer : NSObject


/// 文本内容序列化成TLV格式的二进制数据
/// - Parameters:
///   - text: 要序列化的文本内容（UTF-8编码）
///   - tag: 消息类型标识 详见 TJPContentType
+ (NSData *)serializeText:(NSString *)text tag:(uint16_t)tag;



/// 图片序列化成TLV格式的二进制数据
/// - Parameters:
///   - image: 要序列化的图片
///   - tag: 消息类型标识 详见 TJPContentType
+ (NSData *)serializeImage:(UIImage *)image tag:(uint16_t)tag;



// 后续增加别的消息类型直接增加方法即可

@end

NS_ASSUME_NONNULL_END
