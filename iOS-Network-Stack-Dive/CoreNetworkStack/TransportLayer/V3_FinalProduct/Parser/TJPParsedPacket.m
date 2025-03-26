//
//  TJPParsedPacket.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPParsedPacket.h"

@implementation TJPParsedPacket 

+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header payload:(NSData *)payload {
    TJPParsedPacket *packet = [[TJPParsedPacket alloc] init];
    packet.header = header;
    packet.payload = payload;
    
    packet.messageType = ntohs(header.msgType);  // 需要用ntohs反转消息类型字节序
    packet.sequence = ntohl(header.sequence);    // 使用ntohl转换序列号为主机字节序
    return packet;
}

+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header {
    TJPParsedPacket *packet = [[TJPParsedPacket alloc] init];
    packet.header = header;
    packet.messageType = ntohs(header.msgType);  // 需要用ntohs反转消息类型字节序
    packet.sequence = ntohl(header.sequence);    // 使用ntohl转换序列号为主机字节序
    return packet;
}

@end
