//
//  TJPMessageBuilder.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/14.
//  消息组装类

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageBuilder : NSObject

/// 组装数据包
+ (NSData *)buildPacketWithMessageType:(TJPMessageType)msgType sequence:(uint32_t)sequence payload:(NSData *)payload encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionID:(NSString *)sessionID;

+ (uint16_t)sessionIDFromUUID:(NSString *)uuidString;
@end

NS_ASSUME_NONNULL_END
