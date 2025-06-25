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
// 内容类型
@property (nonatomic, readonly) TJPContentType contentType;
// 消息类型 如普通消息/ACK消息/控制消息
@property (nonatomic, readonly) TJPMessageType messageType;

/// 消息类型
+ (uint16_t)messageTag;
/// TLV数据格式
- (NSData *)tlvData;

@end

NS_ASSUME_NONNULL_END
