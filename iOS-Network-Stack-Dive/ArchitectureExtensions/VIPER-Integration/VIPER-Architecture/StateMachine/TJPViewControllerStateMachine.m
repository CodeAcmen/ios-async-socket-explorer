//
//  TJPViewControllerStateMachine.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/31.
//

#import "TJPViewControllerStateMachine.h"
#import "TJPNetworkDefine.h"


@interface TJPViewControllerStateMachine ()

@property (nonatomic, assign, readwrite) TJPViewControllerState currentState;

@property (nonatomic, strong) NSDictionary<NSNumber *, NSArray<NSNumber *> *> *stateTransitionRules;


@end

@implementation TJPViewControllerStateMachine

#pragma mark - Life Cycle
- (instancetype)initWithInitialState:(TJPViewControllerState)initialState {
    if (self = [super init]) {
        _currentState = initialState;
        
        [self setupStateTransitionRules];
    }
    return self;
}

- (instancetype)init {
    return [self initWithInitialState:TJPViewControllerStateIdle];
}


#pragma mark - Public method
- (BOOL)transitionToState:(TJPViewControllerState)newState {
    // 检查是否为相同状态
    if (self.currentState == newState) {
        return YES;
    }
    
    // 检查状态转换是否合法
    if (![self canTransitionToState:newState]) {
        NSLog(@"[StateMachine] 无效的状态转换: %@ -> %@", [self stateDescription:self.currentState], [self stateDescription:newState]);
        
        if ([self.delegate respondsToSelector:@selector(stateMachine:failedTransitionFromState:toState:)]) {
            [self.delegate stateMachine:self failedTransitionFromState:self.currentState toState:newState];
        }
        
        return NO;
    }
    // 询问代理是否允许状态转换
    if ([self.delegate respondsToSelector:@selector(stateMachine:shouldTransitionFromState:toState:)]) {
        BOOL shouldTransition = [self.delegate stateMachine:self shouldTransitionFromState:self.currentState toState:newState];
        if (!shouldTransition) {
            return NO;
        }
    }
    
    TJPViewControllerState oldState = self.currentState;
    self.currentState = newState;
    
    NSLog(@"[StateMachine] 状态转换: %@ -> %@", [self stateDescription:oldState], [self stateDescription:newState]);
    
    // 通知delegate状态已转换
    if ([self.delegate respondsToSelector:@selector(stateMachine:didTransitionFromState:toState:)]) {
        [self.delegate stateMachine:self didTransitionFromState:oldState toState:newState];
    }
    
    return YES;
}

/// 重置到空闲状态
- (void)resetToIdleState {
    [self transitionToState:TJPViewControllerStateIdle];
}

/// 检查状态转换是否合法
- (BOOL)canTransitionToState:(TJPViewControllerState)newState {
    NSArray *allowedStates = self.stateTransitionRules[@(self.currentState)];
    return [allowedStates containsObject:@(newState)];
}

/// 获取状态描述
- (NSString *)stateDescription:(TJPViewControllerState)state {
    switch (state) {
        case TJPViewControllerStateIdle:
            return @"Idle";
        case TJPViewControllerStateInitialLoading:
            return @"InitialLoading";
        case TJPViewControllerStateContent:
            return @"Content";
        case TJPViewControllerStateRefreshing:
            return @"Refreshing";
        case TJPViewControllerStateLoadingMore:
            return @"LoadingMore";
        case TJPViewControllerStateEmpty:
            return @"Empty";
        case TJPViewControllerStateError:
            return @"Error";
        default:
            return @"Unknown";
    }
}



#pragma mark - Private Method
- (void)setupStateTransitionRules {
    self.stateTransitionRules = @{
        @(TJPViewControllerStateIdle): @[
            @(TJPViewControllerStateInitialLoading),
            @(TJPViewControllerStateError)
        ],
        @(TJPViewControllerStateInitialLoading): @[
            @(TJPViewControllerStateContent),
            @(TJPViewControllerStateEmpty),
            @(TJPViewControllerStateError),
            @(TJPViewControllerStateIdle)
        ],
        @(TJPViewControllerStateContent): @[
            @(TJPViewControllerStateRefreshing),
            @(TJPViewControllerStateLoadingMore),
            @(TJPViewControllerStateError),
            @(TJPViewControllerStateEmpty)
        ],
        @(TJPViewControllerStateRefreshing): @[
            @(TJPViewControllerStateContent),
            @(TJPViewControllerStateEmpty),
            @(TJPViewControllerStateError)
        ],
        @(TJPViewControllerStateLoadingMore): @[
            @(TJPViewControllerStateContent),
            @(TJPViewControllerStateError)
        ],
        @(TJPViewControllerStateEmpty): @[
            @(TJPViewControllerStateInitialLoading),
            @(TJPViewControllerStateRefreshing),
            @(TJPViewControllerStateContent),
            @(TJPViewControllerStateError)
        ],
        @(TJPViewControllerStateError): @[
            @(TJPViewControllerStateInitialLoading),
            @(TJPViewControllerStateRefreshing),
            @(TJPViewControllerStateContent),
            @(TJPViewControllerStateEmpty),
            @(TJPViewControllerStateIdle)
        ]
    };
}

@end
