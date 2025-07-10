//
//  TJPMessageManagerDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//  消息管理器回调代理

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
@class TJPMessageContext;

@protocol TJPMessageManagerDelegate <NSObject>

@required
- (void)messageManager:(id)manager message:(TJPMessageContext *)message didChangeState:(TJPMessageState)newState fromState:(TJPMessageState)oldState;

@optional
- (void)messageManager:(id)manager willSendMessage:(TJPMessageContext *)context;
- (void)messageManager:(id)manager didSendMessage:(TJPMessageContext *)context;
- (void)messageManager:(id)manager didReceiveACK:(TJPMessageContext *)context;
- (void)messageManager:(id)manager didFailToSendMessage:(TJPMessageContext *)context error:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
