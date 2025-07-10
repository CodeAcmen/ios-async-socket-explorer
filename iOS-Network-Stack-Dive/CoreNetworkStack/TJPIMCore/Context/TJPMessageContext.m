//
//  TJPMessageContext.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageContext.h"
#import "TJPNetworkUtil.h"
#import "TJPMessageBuilder.h"
#import "TJPNetworkDefine.h"

@interface TJPMessageContext ()
// 消息内容
@property (nonatomic, strong, readwrite) NSData *payload;


@end

@implementation TJPMessageContext

+ (instancetype)contextWithData:(NSData *)data seq:(uint32_t)seq messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType sessionId:(NSString *)sessionId {
    // 创建上下文实例对象
    TJPMessageContext *context = [TJPMessageContext new];
    context.payload = data;
    context.sequence = seq;
    context.messageType = messageType;
    context.encryptType = encryptType;
    context.compressType = compressType;
    context.sessionId = sessionId;
    
    // 默认重试设置
    context.retryCount = 0;
    context.maxRetryCount = 3;  // 默认最多重试3次
    context.retryTimeout = 3.0; // 默认3秒超时
    
    // 新增初始化
    if (!context.messageId) {
        context.messageId = [[NSUUID UUID] UUIDString];
    }
    context.state = TJPMessageStateCreated;
    context.createTime = [NSDate date];
    

    return context;
}

- (BOOL)isInProgress {
    return self.state == TJPMessageStateSending ||
           self.state == TJPMessageStateRetrying;
}

- (BOOL)isCompleted {
    return self.state == TJPMessageStateRead ||
           self.state == TJPMessageStateCancelled ||
           self.state == TJPMessageStateFailed;
}

- (BOOL)canRetry {
    return self.retryCount < self.maxRetryCount &&
           (self.state == TJPMessageStateFailed || self.state == TJPMessageStateRetrying);
}

- (NSTimeInterval)timeElapsed {
    return [[NSDate date] timeIntervalSinceDate:self.createTime];
}

// 新增状态查询方法
- (BOOL)isWaitingForAck {
    return self.state == TJPMessageStateSending || self.state == TJPMessageStateSent;
}

- (BOOL)needsRetransmission {
    if (![self isWaitingForAck]) {
        return NO;
    }
    
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.sendTime];
    return elapsed > self.retryTimeout;
}

- (NSString *)stateDisplayString {
    switch (self.state) {
        case TJPMessageStateCreated:    return @"已创建";
        case TJPMessageStateSending:    return @"发送中";
        case TJPMessageStateSent:       return @"已发送";
        case TJPMessageStateDelivered:  return @"已送达";
        case TJPMessageStateRead:       return @"已读";
        case TJPMessageStateFailed:     return @"发送失败";
        case TJPMessageStateRetrying:   return @"重试中";
        case TJPMessageStateCancelled:  return @"已取消";
        default: return @"未知状态";
    }
}

- (NSData *)buildRetryPacket {
    _retryCount++;
    // 更新发送时间
    self.sendTime = [NSDate date];
    self.lastRetryTime = [NSDate date];
    
    return [TJPMessageBuilder buildPacketWithMessageType:self.messageType sequence:self.sequence payload:self.payload encryptType:self.encryptType compressType:self.compressType sessionID:self.sessionId];
}


- (BOOL)shouldRetry {
    // 判断是否应该重试
    return (self.retryCount < self.maxRetryCount) &&
           (self.state == TJPMessageStateFailed || self.state == TJPMessageStateRetrying);
}

- (NSTimeInterval)timeElapsedSinceLastSend {
    // 计算自上次发送以来经过的时间
    return [[NSDate date] timeIntervalSinceDate:self.sendTime];
}


@end
