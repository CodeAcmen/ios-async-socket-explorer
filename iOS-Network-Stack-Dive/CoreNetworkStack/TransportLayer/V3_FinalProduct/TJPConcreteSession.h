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

@class TJPNetworkConfig, TJPConnectStateMachine, TJPMessageContext;
@interface TJPConcreteSession : NSObject <TJPSessionProtocol>

/// 独立的sessionId
@property (nonatomic, copy) NSString *sessionId;
/// 待确认消息
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TJPMessageContext *> *pendingMessages;
/// 连接状态机
@property (nonatomic, strong) TJPConnectStateMachine *stateMachine;

@property (nonatomic, weak) id<TJPSessionDelegate> delegate;



- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config;

@end

NS_ASSUME_NONNULL_END
