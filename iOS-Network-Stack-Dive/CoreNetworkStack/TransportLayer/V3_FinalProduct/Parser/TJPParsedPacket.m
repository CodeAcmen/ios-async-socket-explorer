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
    
    return packet;
}

@end
