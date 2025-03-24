//
//  TJPSessionDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
@protocol TJPSessionProtocol;

@protocol TJPSessionDelegate <NSObject>

/// 接收到消息
- (void)session:(id<TJPSessionProtocol>)session didReceiveData:(NSData *)data;
/// 状态改变
- (void)session:(id<TJPSessionProtocol>)session stateChanged:(TJPConnectState)state;


@end

NS_ASSUME_NONNULL_END
