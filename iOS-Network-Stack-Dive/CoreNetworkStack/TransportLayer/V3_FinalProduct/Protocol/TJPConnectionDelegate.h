//
//  TJPConnectionDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/15.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

//简化的连接状态 仅供连接管理类内部使用 后期重构
typedef NS_ENUM(NSInteger, TJPConnectionState) {
    TJPConnectionStateDisconnected,
    TJPConnectionStateConnecting,
    TJPConnectionStateConnected,
    TJPConnectionStateDisconnecting
};

@class TJPConnectionManager;
@protocol TJPConnectionDelegate <NSObject>

@required
/// 已连接
- (void)connectionDidConnect:(TJPConnectionManager *)connection;
/// 断开连接
- (void)connection:(TJPConnectionManager *)connection didDisconnectWithError:(NSError *)error reason:(TJPDisconnectReason)reason;
/// 收到消息
- (void)connection:(TJPConnectionManager *)connection didReceiveData:(NSData *)data;
@optional
/// 将要连接
- (void)connectionWillConnect:(TJPConnectionManager *)connection;
/// 将要断开连接
- (void)connectionWillDisconnect:(TJPConnectionManager *)connection reason:(TJPDisconnectReason)reason;
/// 连接已加密
- (void)connectionDidSecure:(TJPConnectionManager *)connection;

@end

NS_ASSUME_NONNULL_END
