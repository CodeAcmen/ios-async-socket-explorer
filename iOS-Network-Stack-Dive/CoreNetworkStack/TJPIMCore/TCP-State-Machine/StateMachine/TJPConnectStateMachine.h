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

/// 当前状态（只读）
@property (nonatomic, readonly) TJPConnectState currentState;

/// 初始化状态
@property (nonatomic, assign, readonly) BOOL isInitializing;
/// 回调设置标记位
@property (nonatomic, assign, readonly) BOOL hasSetInvalidHandler;


/// 初始化方法
- (instancetype)initWithInitialState:(TJPConnectState)initialState;

/// 初始化方法 - 可选是否自动设置标准转换规则
- (instancetype)initWithInitialState:(TJPConnectState)initialState
                   setupStandardRules:(BOOL)autoSetup;

/// 设置标准转换规则
- (void)setupStandardTransitions;

/// 转换规则
- (void)addTransitionFromState:(TJPConnectState)fromState
                       toState:(TJPConnectState)toState
                      forEvent:(TJPConnectEvent)event;

/// 触发事件
- (void)sendEvent:(TJPConnectEvent)event;

/// 状态变更回调
- (void)onStateChange:(void(^)(TJPConnectState oldState,
                             TJPConnectState newState))handler;

/// 设置无效转换处理器
- (void)setInvalidTransitionHandler:(void (^)(TJPConnectState currentState,
                                           TJPConnectEvent event))handler;

/// 强制设置状态（仅在特殊情况下使用）
- (void)forceState:(TJPConnectState)state;

/// 验证事件在当前状态下是否有效
- (BOOL)canHandleEvent:(TJPConnectEvent)event;

/// Log方法
- (void)logAllTransitions;

@end

NS_ASSUME_NONNULL_END
