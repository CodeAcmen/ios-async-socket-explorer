//
//  TJPViewControllerStateMachine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/31.
//  view状态机 管理状态转换逻辑，不处理UI和业务逻辑

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TJPViewControllerState) {
    TJPViewControllerStateIdle,           // 空闲状态
    TJPViewControllerStateInitialLoading, // 初始加载
    TJPViewControllerStateContent,        // 内容显示
    TJPViewControllerStateRefreshing,     // 刷新中
    TJPViewControllerStateLoadingMore,    // 加载更多
    TJPViewControllerStateEmpty,          // 空数据
    TJPViewControllerStateError           // 错误状态
};

@protocol TJPViewControllerStateMachineDelegate <NSObject>
@optional
/// 状态转换前的回调 - 可以阻止状态转换
- (BOOL)stateMachine:(id)stateMachine shouldTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState;

/// 状态转换后的回调
- (void)stateMachine:(id)stateMachine didTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState;

/// 状态转换失败的回调
- (void)stateMachine:(id)stateMachine failedTransitionFromState:(TJPViewControllerState)fromState toState:(TJPViewControllerState)toState;

@end

@interface TJPViewControllerStateMachine : NSObject

@property (nonatomic, assign, readonly) TJPViewControllerState currentState;
@property (nonatomic, weak) id<TJPViewControllerStateMachineDelegate> delegate;

/// 初始化状态机
- (instancetype)initWithInitialState:(TJPViewControllerState)initialState;

/// 尝试转换状态
- (BOOL)transitionToState:(TJPViewControllerState)newState;

/// 重置到空闲状态
- (void)resetToIdleState;

/// 检查状态转换是否合法
- (BOOL)canTransitionToState:(TJPViewControllerState)newState;

/// 获取状态描述
- (NSString *)stateDescription:(TJPViewControllerState)state;

@end

NS_ASSUME_NONNULL_END
