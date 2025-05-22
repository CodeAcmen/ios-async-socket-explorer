//
//  TJPMessageContext.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageContext.h"
#import "TJPNetworkUtil.h"
#import "TJPMessageBuilder.h"

@interface TJPMessageContext ()

@end

@implementation TJPMessageContext {
    //原始数据
    NSData *_originData;
}

+ (instancetype)contextWithData:(NSData *)data seq:(uint32_t)seq messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionId:(NSString *)sessionId {
    TJPMessageContext *context = [TJPMessageContext new];
    context->_originData = data;
    context.sendTime = [NSDate date];
    context.retryCount = 0;
    context.sequence = seq;
    context.messageType = messageType;
    context.encryptType = encryptType;
    context.compressType = compressType;
    context.sessionId = sessionId;
    
    
    context.maxRetryCount = 3;  // 默认最多重试3次
    context.retryTimeout = 3.0; // 默认3秒超时

    return context;
}

- (NSData *)buildRetryPacket {
    _retryCount++;
    self.sendTime = [NSDate date]; // 更新发送时间
    return [TJPMessageBuilder buildPacketWithMessageType:self.messageType sequence:self.sequence payload:_originData encryptType:self.encryptType compressType:self.compressType sessionID:self.sessionId];
}


- (BOOL)shouldRetry {
    // 判断是否应该重试
    return (self.retryCount < self.maxRetryCount);
}

- (NSTimeInterval)timeElapsedSinceLastSend {
    // 计算自上次发送以来经过的时间
    return [[NSDate date] timeIntervalSinceDate:self.sendTime];
}


@end
