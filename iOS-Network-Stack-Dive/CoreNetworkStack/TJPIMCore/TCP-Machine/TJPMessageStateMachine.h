//
//  TJPMessageStateMachine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//  消息状态机

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

@class TJPMessageContext;
NS_ASSUME_NONNULL_BEGIN

@interface TJPMessageStateMachine : NSObject
/// 消息id
@property (nonatomic, copy) NSString *messageId;
/// 当前消息状态
@property (nonatomic, assign, readonly) TJPMessageState currentState;

/// 状态回调
@property (nonatomic, copy) void(^stateChangeCallback)(TJPMessageContext *context, TJPMessageState oldState, TJPMessageState newState);

/// 初始化方法
- (instancetype)initWithMessageId:(NSString *)messageId;
- (instancetype)initWithMessageId:(NSString *)messageId initialState:(TJPMessageState)initialState;

/**
 * 验证状态转换是否合法
 */
- (BOOL)canTransitionFrom:(TJPMessageState)fromState to:(TJPMessageState)toState;
- (void)transitionToState:(TJPMessageState)newState context:(TJPMessageContext *)context;

- (NSString *)stateDisplayString;

+ (BOOL)isTerminalState:(TJPMessageState)state;

@end

NS_ASSUME_NONNULL_END
