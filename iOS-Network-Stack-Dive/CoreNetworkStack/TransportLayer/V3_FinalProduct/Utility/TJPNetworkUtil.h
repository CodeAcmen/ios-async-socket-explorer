//
//  TJPNetworkUtil.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPNetworkUtil : NSObject

/// crc32校验
+ (uint32_t)crc32ForData:(NSData *)data;

/// 使用zlib 数据压缩  
+ (NSData *)compressData:(NSData *)data;

/// 数据解压
+ (NSData *)decompressData:(NSData *)data;

+ (NSString *)base64EncodeData:(NSData *)data;
+ (NSData *)base64DecodeString:(NSString *)string;

/// 获取当前设备IP地址
+ (NSString *)deviceIPAddress;
+ (BOOL)isValidIPAddress:(NSString *)ip;


@end

NS_ASSUME_NONNULL_END
