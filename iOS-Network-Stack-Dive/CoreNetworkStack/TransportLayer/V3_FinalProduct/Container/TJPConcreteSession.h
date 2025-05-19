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

@class TJPNetworkConfig, TJPConnectStateMachine, TJPMessageContext, TJPReconnectPolicy, TJPConnectionManager;

@interface TJPConcreteSession : NSObject <TJPSessionProtocol>

@property (nonatomic, weak) id<TJPSessionDelegate> delegate;

/// 独立的sessionId
@property (nonatomic, copy) NSString *sessionId;

@property (nonatomic, assign) TJPSessionType sessionType;

/// 配置
@property (nonatomic, strong) TJPNetworkConfig *config;

/// 连接状态机
@property (nonatomic, strong) TJPConnectStateMachine *stateMachine;

/// 重试策略
@property (nonatomic, strong) TJPReconnectPolicy *reconnectPolicy;

/// 待确认消息
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPMessageContext *> *pendingMessages;

/// 断开原因
@property (nonatomic, assign) TJPDisconnectReason disconnectReason;

/// 重连标志符
@property (atomic, assign) BOOL isReconnecting;

/// 是否允许自动重连 默认开启
@property (nonatomic, assign) BOOL autoReconnectEnabled;


/// 初始化方法
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config;
//- (void)disconnect;
//- (void)forceReconnect;
//- (void)prepareForRelease;

//*****************************************************
//   埋点统计 具体实现看TJPConcreteSession+TJPMetrics.h 通过hook相关方法增加埋点
- (void)handleACKForSequence:(uint32_t)sequence;
- (void)disconnectWithReason:(TJPDisconnectReason)reason;
- (void)connection:(TJPConnectionManager *)connection didDisconnectWithError:(NSError *)error reason:(TJPDisconnectReason)reason;
- (void)handleRetransmissionForSequence:(uint32_t)sequence;
- (void)performVersionHandshake;
//*****************************************************

@end

NS_ASSUME_NONNULL_END
