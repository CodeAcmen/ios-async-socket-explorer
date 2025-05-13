//
//  TJPMessageSerializer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPMessageSerializer.h"

@implementation TJPMessageSerializer

+ (NSData *)serializeText:(NSString *)text tag:(uint16_t)tag {
    NSData *textData = [text dataUsingEncoding:NSUTF8StringEncoding];
    return [self buildTLVWithTag:tag value:textData];
}

+ (NSData *)buildTLVWithTag:(uint16_t)tag value:(NSData *)value {
    uint16_t netTag = CFSwapInt16HostToBig(tag);
    uint32_t netLength = CFSwapInt32HostToBig((uint32_t)value.length);
    
    NSMutableData *data = [NSMutableData dataWithBytes:&netTag length:2];
    [data appendBytes:&netLength length:4];
    [data appendData:value];
    
    return [data copy];
}

@end
