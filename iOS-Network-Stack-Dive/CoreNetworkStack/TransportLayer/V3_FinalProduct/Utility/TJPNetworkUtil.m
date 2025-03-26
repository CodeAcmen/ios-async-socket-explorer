//
//  TJPNetworkUtil.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/23.
//

#import "TJPNetworkUtil.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <zlib.h>

@implementation TJPNetworkUtil


+ (NSData *)buildPacketWithData:(NSData *)data type:(TJPMessageType)type sequence:(uint32_t)sequence {
    
    //初始化协议头
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.version_major = kProtocolVersionMajor;
    header.version_minor = kProtocolVersionMinor;
    header.msgType = htons(type);
    header.sequence = htonl(sequence);
    header.bodyLength = htonl((uint32_t)data.length);
    //crc32ForData需要转换为网络字节序
    header.checksum = htonl([self crc32ForData:data]);
    
    //构建完整包
    NSMutableData *packet = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [packet appendData:data];
    return packet;
        
}

+ (uint32_t)crc32ForData:(NSData *)data {
    uLong crc = crc32(0L, Z_NULL, 0);
    crc = crc32(crc, [data bytes], (uInt)[data length]);
    
    NSLog(@"Calculated CRC32: %u", (uint32_t)crc);  // 输出计算的 CRC32 值
    return (uint32_t)crc;
}



+ (NSData *)compressData:(NSData *)data {
    if (data.length == 0) return data;
    
    //设置zlib压缩流属性
    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    //输入数据的长度
    stream.avail_in = (uint)data.length;
    //输出数据的长度
    stream.next_in = (Bytef *)data.bytes;
    //输出数据总长度
    stream.total_out = 0;
    
    //关键步骤 初始化压缩流
    if (deflateInit(&stream, Z_DEFAULT_COMPRESSION) != Z_OK) {
        return nil;
    }
    
    //分配16k的缓冲区用于存储压缩后的数据
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];
    while (stream.avail_out == 0) {
        if (stream.total_out >= compressed.length) {
            //如果初始化16k不够则再增加16k
            [compressed increaseLengthBy:16384];
        }
        
        //输出数据的位置
        stream.next_out = compressed.mutableBytes + stream.total_out;
        //输出数据的剩余空间
        stream.avail_out = (uint)(compressed.length - stream.total_out);
        //关键步骤 开始压缩
        deflate(&stream, Z_FINISH);
    }
    
    //关键步骤 结束压缩并释放资源
    deflateEnd(&stream);
    //压缩后的实际长度
    compressed.length = stream.total_out;
    return compressed;
}

+ (NSData *)decompressData:(NSData *)data {
    if (data.length == 0) return data;
    
    //设置解压流属性
    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.avail_in = (uint)data.length;
    stream.next_in = (Bytef *)data.bytes;
    stream.total_out = 0;
    
    //关键步骤 初始化解压流
    if (inflateInit(&stream) != Z_OK) {
        return nil;
    }
    
    //初始化缓冲区空间
    NSMutableData *decompressed = [NSMutableData dataWithLength:data.length * 2];
    while (stream.avail_out == 0) {
        if (stream.total_out >= decompressed.length) {
            [decompressed increaseLengthBy:data.length];
        }
        
        //输出数据的位置
        stream.next_out = decompressed.mutableBytes + stream.total_out;
        //输出数据的剩余空间
        stream.avail_out = (uint)(decompressed.length - stream.total_out);
        //关键步骤 执行解压操作
        inflate(&stream, Z_FINISH);
    }
    
    //关键步骤 结束解压并释放相关资源
    inflateEnd(&stream);
    //解压后的实际大小
    decompressed.length = stream.total_out;
    return decompressed;
}

#pragma mark - 数据编码
+ (NSString *)base64EncodeData:(NSData *)data {
    return [data base64EncodedStringWithOptions:0];
}

+ (NSData *)base64DecodeString:(NSString *)string {
    return [[NSData alloc] initWithBase64EncodedString:string options:0];
}

#pragma mark - 网络工具
+ (NSString *)deviceIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        struct ifaddrs *addr = interfaces;
        while (addr != NULL) {
            if (addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:
                               inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
                    break;
                }
            }
            addr = addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return address;
}

+ (BOOL)isValidIPAddress:(NSString *)ip {
    const char *utf8 = [ip UTF8String];
    struct in_addr dst;
    return (inet_pton(AF_INET, utf8, &dst) == 1);
}

@end




