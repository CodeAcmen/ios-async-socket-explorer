//
//  TJPConnectStateMachine.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/24.
//

#import "TJPConnectStateMachine.h"
#import "JZNetworkDefine.h"

TJPConnectState const TJPConnectStateDisconnected = @"Disconnected";
TJPConnectState const TJPConnectStateConnecting = @"Connecting";
TJPConnectState const TJPConnectStateConnected = @"Connected";
TJPConnectState const TJPConnectStateDisconnecting = @"Disconnecting";

TJPConnectEvent const TJPConnectEventConnect = @"Connect";                              //连接事件
TJPConnectEvent const TJPConnectEventConnectSuccess = @"ConnectSuccess";                //连接成功事件
TJPConnectEvent const TJPConnectEventConnectFailed = @"Failed";                         //连接错误事件
TJPConnectEvent const TJPConnectEventDisconnect = @"Disconnect";                        //断开连接事件
TJPConnectEvent const TJPConnectEventDisconnectComplete = @"DisconnectComplete";        //断开完成事件
TJPConnectEvent const TJPConnectEventForceDisconnect = @"ForceDisconnect";              //强制断开事件

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
    if (![self validateTransitionFromState:fromState toState:toState forEvent:event]) {
        return;
    }
    
    NSString *key = [NSString stringWithFormat:@"%@:%@", fromState, event];
    _transitions[key] = toState;
//    TJPLOG_INFO(@"添加状态转换: %@ -> %@", key, toState);
}

- (void)sendEvent:(TJPConnectEvent)event {
    if (self.currentState == TJPConnectStateConnecting &&
        [event isEqualToString:TJPConnectEventConnect]) {
        TJPLOG_INFO(@"连接已在进行中，保持状态");
        return;
    }
    
    TJPLOG_INFO(@"发送事件 :%@", event);
    NSString *key = [NSString stringWithFormat:@"%@:%@", _currentState, event];
    TJPLOG_INFO(@"查找转换规则的 key: %@", key);

    TJPConnectState newState = _transitions[key];
    TJPLOG_INFO(@"新状态为 :%@", newState);
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


// 添加状态预检逻辑
- (BOOL)validateTransitionFromState:(TJPConnectState)fromState toState:(TJPConnectState)toState forEvent:(TJPConnectEvent)event {
    // 示例：禁止从 Connected 直接到 Connecting
    if ([fromState isEqualToString:TJPConnectStateConnected] &&
        [event isEqualToString:TJPConnectEventConnect]) {
        TJPLOG_ERROR(@"禁止从 Connected 直接到 Connecting");
        return NO;
    }
    return YES;
}


- (BOOL)canSendEvent:(TJPConnectEvent)event {
    NSString *key = [NSString stringWithFormat:@"%@:%@", _currentState, event];
    return _transitions[key] != nil;
}


- (void)onStateChange:(void (^)(TJPConnectState _Nonnull, TJPConnectState _Nonnull))handler {
    [_stateChangeHandlers addObject:handler];
}


- (void)logAllTransitions {
    TJPLOG_INFO(@"当前状态转换表：");
    for (NSString *key in _transitions) {
        TJPLOG_INFO(@"%@ -> %@", key, _transitions[key]);
    }
}


@end
