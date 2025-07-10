//
//  TJPMessageManagerNetworkDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/24.
//  网络发送代理协议

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TJPMessageManager, TJPMessageContext;

@protocol TJPMessageManagerNetworkDelegate <NSObject>
/**
 * 请求网络层发送消息
 */
- (void)messageManager:(TJPMessageManager *)manager needsSendMessage:(TJPMessageContext *)message;

@optional
/**
 * 请求网络层重传消息
 */
- (void)messageManager:(TJPMessageManager *)manager needsRetransmitMessage:(TJPMessageContext *)message;

@end

NS_ASSUME_NONNULL_END
