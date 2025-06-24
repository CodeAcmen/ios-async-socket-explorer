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

/// 独立的会话id
@property (nonatomic, copy) NSString *sessionId;

/// 会话类型
@property (nonatomic, assign) TJPSessionType sessionType;

/// 配置
@property (nonatomic, strong) TJPNetworkConfig *config;

/// 连接状态机
@property (nonatomic, strong) TJPConnectStateMachine *stateMachine;

/// 重试策略
@property (nonatomic, strong) TJPReconnectPolicy *reconnectPolicy;

/// 待确认消息  改为以消息ID为key
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPMessageContext *> *pendingMessages;

/// 序列号到消息ID映射
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *sequenceToMessageId;


/// 断开原因
@property (nonatomic, assign) TJPDisconnectReason disconnectReason;

/// 重连标志符
@property (atomic, assign) BOOL isReconnecting;

/// 是否允许自动重连 默认开启
@property (nonatomic, assign) BOOL autoReconnectEnabled;

// 创建时间
@property (nonatomic, readonly) NSDate *createdTime;



/// 初始化方法
- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config;

//*****************************************************
//   埋点统计 具体实现看TJPConcreteSession+TJPMetrics.h 通过hook相关方法增加埋点
- (void)handleACKForSequence:(uint32_t)sequence;
- (void)disconnectWithReason:(TJPDisconnectReason)reason;
- (void)connection:(TJPConnectionManager *)connection didDisconnectWithError:(NSError *)error reason:(TJPDisconnectReason)reason;
- (void)handleRetransmissionForSequence:(uint32_t)sequence;
- (void)performVersionHandshake;
//*****************************************************

//*****************************************************
//  多路复用支持相关

/// 最后活跃时间
@property (nonatomic, strong) NSDate *lastActiveTime;
/// 最后释放时间
@property (nonatomic, strong) NSDate *lastReleaseTime;
/// 使用次数
@property (nonatomic, assign) NSUInteger useCount;
/// 是否在池中
@property (nonatomic, assign) BOOL isPooled;

- (void)resetForReuse;
- (BOOL)checkHealthyForSession;

//*****************************************************


@end

NS_ASSUME_NONNULL_END
