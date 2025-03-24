//
//  TJPConnectStateMachine.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/24.
//

#import "TJPConnectStateMachine.h"
#import "JZNetworkDefine.h"

@interface TJPConnectStateMachine ()

@end

@implementation TJPConnectStateMachine {
    TJPConnectState _currentState;
    NSMutableDictionary<NSString *, TJPConnectState> *_transitions;
    NSMutableArray<void (^)(TJPConnectState, TJPConnectState)> *_stateChangeHandlers;
}


- (instancetype)initWithInitialState:(TJPConnectState)initialState {
    if (self = [super init]) {
        _currentState = initialState;
        _transitions = [NSMutableDictionary dictionary];
        _stateChangeHandlers = [NSMutableArray array];
    }
    return self;
}

- (void)addTransitionFromState:(TJPConnectState)fromState toState:(TJPConnectState)toState forEvent:(TJPConnectEvent)event {
    NSString *key = [NSString stringWithFormat:@"%@:%@", fromState, event];
    _transitions[key] = toState;
}

- (void)sendEvent:(TJPConnectEvent)event {
    NSString *key = [NSString stringWithFormat:@"%@:%@", _currentState, event];
    TJPConnectState newState = _transitions[key];
    
    if (newState) {
        TJPConnectState oldState = _currentState;
        _currentState = newState;
        
        //状态变更回调
        for (void(^handler)(TJPConnectState, TJPConnectState) in _stateChangeHandlers) {
            handler(oldState, newState);
        }
    }else {
        TJPLOG_INFO(@"无效的状态转换 旧状态:%@ ->旧状态事件:%@", _currentState, event);
    }
}

- (void)onStateChange:(void (^)(TJPConnectState _Nonnull, TJPConnectState _Nonnull))handler {
    [_stateChangeHandlers addObject:handler];
}



@end


