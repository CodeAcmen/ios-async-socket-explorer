//
//  TJPMessageContext.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageContext.h"
#import "TJPNetworkUtil.h"

@interface TJPMessageContext ()

@end

@implementation TJPMessageContext {
    //原始数据
    NSData *_originData;
}

+ (instancetype)contextWithData:(NSData *)data seq:(uint32_t)seq {
    TJPMessageContext *context = [TJPMessageContext new];
    context->_originData = data;
    context.sendTime = [NSDate date];
    context.retryCount = 0;
    context.sequence = seq;
    return context;
}

- (NSData *)buildRetryPacket {
    _retryCount++;
    return [TJPNetworkUtil buildPacketWithData:_originData type:TJPMessageTypeNormalData sequence:_sequence];
}
@end
