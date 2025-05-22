//
//  TJPMessageProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  消息接口

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TJPMessageProtocol <NSObject>

@required

@property (nonatomic, readonly) TJPContentType contentType;

/// 消息类型
+ (uint16_t)messageTag;
/// TLV数据格式
- (NSData *)tlvData;

@end

NS_ASSUME_NONNULL_END
