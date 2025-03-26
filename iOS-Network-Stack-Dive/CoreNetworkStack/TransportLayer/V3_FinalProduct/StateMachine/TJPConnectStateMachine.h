//
//  TJPConnectStateMachine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/24.
//  连接状态机

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPConnectStateMachine : NSObject

@property (nonatomic, readonly) TJPConnectState currentState;

- (instancetype)initWithInitialState:(TJPConnectState)initialState;

/// 转换规则
- (void)addTransitionFromState:(TJPConnectState)fromState toState:(TJPConnectState)toState forEvent:(TJPConnectEvent)event;

/// 触发事件
- (void)sendEvent:(TJPConnectEvent)event;

/// 状态变更回调
- (void)onStateChange:(void(^)(TJPConnectState oldState, TJPConnectState newState))handler;

/// log方法
- (void)logAllTransitions;
@end

NS_ASSUME_NONNULL_END
