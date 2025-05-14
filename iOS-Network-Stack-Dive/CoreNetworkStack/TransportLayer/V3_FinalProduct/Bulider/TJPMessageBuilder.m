//
//  TJPMessageBuilder.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/14.
//

#import "TJPMessageBuilder.h"
#import "TJPNetworkDefine.h"
#import "TJPNetworkUtil.h"

@implementation TJPMessageBuilder


+ (NSData *)buildPacketWithMessageType:(TJPMessageType)msgType sequence:(uint32_t)sequence payload:(NSData *)payload encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionID:(NSString *)sessionID {
    if (!payload) {
        payload = [NSData data]; // 空载荷使用空数据
    }
    
    // 确保数据大小不超过限制
    if (payload.length > TJPMAX_BODY_SIZE) {
        TJPLOG_ERROR(@"负载数据过大: %lu > %d", (unsigned long)payload.length, TJPMAX_BODY_SIZE);
        return nil;
    }
    
    // 初始化协议头
    TJPFinalAdavancedHeader header = {0};
    //网络字节序转换
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(msgType);
    header.sequence = htonl(sequence);
    header.timestamp = htonl((uint32_t)[[NSDate date] timeIntervalSince1970]); // 当前时间戳
    header.encrypt_type = encryptType;
    header.compress_type = compressType;
    header.session_id = htons([self sessionIDFromUUID:sessionID]);

    
    header.bodyLength = htonl((uint32_t)payload.length);
    
    // 计算数据体的CRC32
    uint32_t checksum = [TJPNetworkUtil crc32ForData:payload];
    header.checksum = htonl(checksum);  // 注意要转换为网络字节序
    
    // 构建完整协议包
    NSMutableData *packet = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [packet appendData:payload];
    return packet;
}

// 从UUID字符串生成16位会话ID
+ (uint16_t)sessionIDFromUUID:(NSString *)uuidString {
    if (!uuidString || uuidString.length == 0) {
        return 0;
    }
    
    // 移除UUID中的"-"字符
    NSString *cleanUUID = [uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    // 取UUID的前8个字符，转换为32位整数
    NSString *prefix = [cleanUUID substringToIndex:MIN(8, cleanUUID.length)];
    unsigned int value = 0;
    [[NSScanner scannerWithString:prefix] scanHexInt:&value];
    
    // 折叠32位值为16位：XOR高16位和低16位
    uint16_t highPart = (uint16_t)(value >> 16);
    uint16_t lowPart = (uint16_t)(value & 0xFFFF);
    
    return highPart ^ lowPart; // XOR操作保持更好的分布
}

@end
