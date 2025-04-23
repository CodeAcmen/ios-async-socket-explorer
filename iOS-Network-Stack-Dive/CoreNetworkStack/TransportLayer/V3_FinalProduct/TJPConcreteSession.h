//
//  TJPConcreteSession.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  会话类 核心之一

#import <Foundation/Foundation.h>
#import "TJPSessionProtocol.h"
#import "TJPSessionDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPNetworkConfig, TJPConnectStateMachine, TJPMessageContext, TJPReconnectPolicy;
@interface TJPConcreteSession : NSObject <TJPSessionProtocol>

/// 连接状态机
@property (nonatomic, strong) TJPConnectStateMachine *stateMachine;
/// 独立的sessionId
@property (nonatomic, copy) NSString *sessionId;
/// 待确认消息
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPMessageContext *> *pendingMessages;
/// 重试策略
@property (nonatomic, strong) TJPReconnectPolicy *reconnectPolicy;

@property (nonatomic, weak) id<TJPSessionDelegate> delegate;


@property (nonatomic, assign) TJPDisconnectReason disconnectReason; // 断开原因
/// 是否允许自动重连 默认开启
@property (nonatomic, assign) BOOL autoReconnectEnabled;



/// 初始化方法
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config;

@end

NS_ASSUME_NONNULL_END
