//
//  TJPIMClient.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  TCP框架入口 门面设计模式屏蔽底层实现

#import <Foundation/Foundation.h>
#import "TJPMessageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPIMClient : NSObject

/// 单例类
+ (instancetype)shared;

/**
 * 使用默认会话类型
 */
- (void)connectToHost:(NSString *)host port:(uint16_t)port;

/**
 * 连接指定类型的会话
 */
- (void)connectToHost:(NSString *)host port:(uint16_t)port forType:(TJPSessionType)type;

/**
 * 断开指定类型的会话
 */
- (void)disconnectSessionType:(TJPSessionType)type;

/**
 * 断开所有会话
 */
- (void)disconnectAll;

/**
 * 兼容原有方法（断开默认会话）
 */
- (void)disconnect;


/**
 * 通过指定类型的会话发送消息
 */
- (void)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type;

/**
 * 兼容原有方法（使用默认会话类型）
 */
- (void)sendMessage:(id<TJPMessageProtocol>)message;

/**
 * 自动路由发送消息
 */
- (void)sendMessageWithAutoRoute:(id<TJPMessageProtocol>)message;

/**
 * 带回调的发送方法
 */
- (NSString *)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type completion:(void(^)(NSString *msgId, NSError *error))completion;
- (NSString *)sendMessage:(id<TJPMessageProtocol>)message throughType:(TJPSessionType)type encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType completion:(void (^)(NSString *msgId, NSError *error))completion;
/**
 * 检查指定类型的会话是否已连接
 */
- (BOOL)isConnectedForType:(TJPSessionType)type;

/**
 * 检查指定类型的会话是否已断开连接
 */
- (BOOL)isDisConnectedForType:(TJPSessionType)type;

/**
 * 获取指定类型会话的连接状态
 */
- (TJPConnectState)getConnectionStateForType:(TJPSessionType)type;

/**
 * 配置消息内容类型到会话类型的路由
 */
- (void)configureRouting:(TJPContentType)contentType toSessionType:(TJPSessionType)sessionType;


/**
 * 获取所有连接状态
 */
- (NSDictionary<NSNumber *, TJPConnectState> *)getAllConnectionStates;


- (BOOL)isStateConnected:(TJPConnectState)state;
- (BOOL)isStateConnecting:(TJPConnectState)state;
- (BOOL)isStateDisconnected:(TJPConnectState)state;
- (BOOL)isStateDisconnecting:(TJPConnectState)state;
- (BOOL)isStateConnectedOrConnecting:(TJPConnectState)state;
- (BOOL)isStateDisconnectedOrDisconnecting:(TJPConnectState)state;
@end

NS_ASSUME_NONNULL_END
