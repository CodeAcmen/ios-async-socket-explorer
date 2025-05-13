//
//  TJPMessage.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPMessage <NSObject>

@required
/// 消息类型
+ (uint16_t)messageTag;
/// TLV数据格式
- (NSData *)tlvData;

@end

NS_ASSUME_NONNULL_END
