//
//  TJPNETError.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TJPNETErrorCode) {
    TJPNETErrorConnectionFailed = 1000,   // 连接失败
    TJPNETErrorHeartbeatTimeout,          // 心跳超时
    TJPNETErrorInvalidProtocol,           // 协议错误（魔数校验失败）
    TJPNETErrorSSLHandshakeFailed,        // SSL握手失败
    TJPNETErrorDataCorrupted,             // 数据校验失败
    TJPNETErrorACKTimeout                 // ACK确认超时
};

NS_ASSUME_NONNULL_BEGIN

@interface TJPNETError : NSError

+ (instancetype)errorWithCode:(TJPNETErrorCode)code userInfo:(NSDictionary *)dict;


@end

NS_ASSUME_NONNULL_END
