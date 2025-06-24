//
//  TJPMessageStateMachine.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import "TJPMessageStateMachine.h"
#import "TJPMessageContext.h"
#import "TJPNetworkDefine.h"

@interface TJPMessageStateMachine ()

@property (nonatomic, assign, readwrite) TJPMessageState currentState;


@end

@implementation TJPMessageStateMachine

- (instancetype)initWithMessageId:(NSString *)messageId {
    if (self = [super init]) {
        _messageId = [messageId copy];
        // 消息初试状态
        _currentState = TJPMessageStateCreated;
    }
    return self;
}

- (instancetype)initWithMessageId:(NSString *)messageId initialState:(TJPMessageState)initialState {
    if (self = [super init]) {
        _messageId = [messageId copy];
        _currentState = initialState;
    }
    return self;
}

- (BOOL)canTransitionFrom:(TJPMessageState)fromState to:(TJPMessageState)toState {
    // 防止自环转换
    if (fromState == toState && fromState != TJPMessageStateRetrying) {
        return NO;
    }
    
    // 状态转换规则矩阵
    static NSDictionary<NSNumber *, NSSet<NSNumber *> *> *transitionRules;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        transitionRules = @{
            // 创建状态 -> 可转换为发送中、已取消
            @(TJPMessageStateCreated): [NSSet setWithObjects:@(TJPMessageStateSending), @(TJPMessageStateCancelled), nil],
            
            // 发送中 -> 可转换为已发送、发送失败、已取消
            @(TJPMessageStateSending): [NSSet setWithObjects:@(TJPMessageStateSent), @(TJPMessageStateFailed), @(TJPMessageStateCancelled), nil],
            
            // 已发送 -> 可转换为已送达、发送失败
            @(TJPMessageStateSent): [NSSet setWithObjects:@(TJPMessageStateDelivered), @(TJPMessageStateFailed), nil],
            
            // 重试中 -> 可转换为发送中、发送失败、已取消
            @(TJPMessageStateRetrying): [NSSet setWithObjects:@(TJPMessageStateSending), @(TJPMessageStateFailed), @(TJPMessageStateCancelled), nil],
            
            // 发送失败 -> 可转换为重试中、已取消
            @(TJPMessageStateFailed): [NSSet setWithObjects:@(TJPMessageStateRetrying), @(TJPMessageStateCancelled), nil],
            
            // 已送达 -> 可转换为已读
            @(TJPMessageStateDelivered): [NSSet setWithObjects:@(TJPMessageStateRead), nil],
            
            // 终态：已读、已取消 - 不能转换到其他状态
            @(TJPMessageStateRead): [NSSet set], // 终态
            @(TJPMessageStateCancelled): [NSSet set] // 终态
        };
    });
    
    NSSet *allowedStates = transitionRules[@(fromState)];
    return [allowedStates containsObject:@(toState)];
}

- (void)transitionToState:(TJPMessageState)newState context:(TJPMessageContext *)context {
    if (![self canTransitionFrom:_currentState to:newState]) {
        TJPLOG_ERROR(@"[TJPMessageStateMachine] 无效状态转换: %@ -> %@",
                     [self stateDisplayString], [self stateStringForState:newState]);

        return;
    }
    
    TJPMessageState oldState = _currentState;
    _currentState = newState;
    context.state = newState;
    
    // 更新时间戳
    switch (newState) {
        case TJPMessageStateSending:
            context.sendTime = [NSDate date];
            break;
        case TJPMessageStateSent:
            // 已发送状态不需要再更新发送时间
            break;
        case TJPMessageStateDelivered:
            context.deliveredTime = [NSDate date];
            break;
        case TJPMessageStateRead:
            context.readTime = [NSDate date];
            break;
        case TJPMessageStateRetrying:
            context.lastRetryTime = [NSDate date];
            context.retryCount++; // 增加重试次数
            break;
        default:
            break;
    }
    
    // 触发回调
    if (self.stateChangeCallback) {
        self.stateChangeCallback(context, oldState, newState);
    }
    
    TJPLOG_INFO(@"[TJPMessageStateMachine] 消息 %@ 状态转换: %@ -> %@",
                self.messageId, [self stateStringForState:oldState], [self stateDisplayString]);
}

- (NSString *)stateDisplayString {
    return [self stateStringForState:self.currentState];
}

- (NSString *)stateStringForState:(TJPMessageState)state {
    switch (state) {
        case TJPMessageStateCreated:    return @"已创建";
        case TJPMessageStateSending:    return @"发送中";
        case TJPMessageStateSent:       return @"已发送";
        case TJPMessageStateDelivered:  return @"已送达";
        case TJPMessageStateRead:       return @"已读";
        case TJPMessageStateFailed:     return @"发送失败";
        case TJPMessageStateRetrying:   return @"重试中";
        case TJPMessageStateCancelled:  return @"已取消";
        default: return @"未知状态";
    }
}

+ (BOOL)isTerminalState:(TJPMessageState)state {
    return state == TJPMessageStateRead ||
           state == TJPMessageStateCancelled ||
           state == TJPMessageStateFailed;
}

+ (NSArray<NSNumber *> *)possibleNextStatesFrom:(TJPMessageState)state {
    static NSDictionary<NSNumber *, NSArray<NSNumber *> *> *nextStates;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nextStates = @{
            @(TJPMessageStateCreated): @[@(TJPMessageStateSending), @(TJPMessageStateCancelled)],
            @(TJPMessageStateSending): @[@(TJPMessageStateSent), @(TJPMessageStateFailed), @(TJPMessageStateCancelled)],
            @(TJPMessageStateSent): @[@(TJPMessageStateDelivered), @(TJPMessageStateFailed)],
            @(TJPMessageStateDelivered): @[@(TJPMessageStateRead)],
            @(TJPMessageStateFailed): @[@(TJPMessageStateRetrying), @(TJPMessageStateCancelled)],
            @(TJPMessageStateRetrying): @[@(TJPMessageStateSending), @(TJPMessageStateFailed), @(TJPMessageStateCancelled)],
            @(TJPMessageStateRead): @[],
            @(TJPMessageStateCancelled): @[]
        };
    });
    return nextStates[@(state)] ?: @[];
}


@end
