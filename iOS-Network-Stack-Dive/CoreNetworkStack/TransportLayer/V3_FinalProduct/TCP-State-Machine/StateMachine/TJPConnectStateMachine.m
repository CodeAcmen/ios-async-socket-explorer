//
//  TJPConnectStateMachine.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/24.
//

#import "TJPConnectStateMachine.h"
#import "TJPNetworkDefine.h"

TJPConnectState const TJPConnectStateDisconnected = @"Disconnected";
TJPConnectState const TJPConnectStateConnecting = @"Connecting";
TJPConnectState const TJPConnectStateConnected = @"Connected";
TJPConnectState const TJPConnectStateDisconnecting = @"Disconnecting";

TJPConnectEvent const TJPConnectEventConnect = @"Connect";                              //连接事件
TJPConnectEvent const TJPConnectEventConnectSuccess = @"ConnectSuccess";                //连接成功事件
TJPConnectEvent const TJPConnectEventConnectFailed = @"Failed";                         //连接错误事件
TJPConnectEvent const TJPConnectEventNetworkError = @"NetworkError";                    // 网络错误事件
TJPConnectEvent const TJPConnectEventDisconnect = @"Disconnect";                        //断开连接事件
TJPConnectEvent const TJPConnectEventDisconnectComplete = @"DisconnectComplete";        //断开完成事件
TJPConnectEvent const TJPConnectEventForceDisconnect = @"ForceDisconnect";              //强制断开事件

@interface TJPConnectStateMachine ()

@end

@implementation TJPConnectStateMachine {
    dispatch_queue_t _eventQueue;
    NSMutableDictionary<NSString *, TJPConnectState> *_transitions;
    NSMutableArray<void (^)(TJPConnectState, TJPConnectState)> *_stateChangeHandlers;
}


- (instancetype)initWithInitialState:(TJPConnectState)initialState {
    if (self = [super init]) {
        // 通过 setter 设置初始状态，触发 swizzled setCurrentState:
        self.currentState = initialState;
        _transitions = [NSMutableDictionary dictionary];
        _stateChangeHandlers = [NSMutableArray array];
        _eventQueue = dispatch_queue_create("com.statemachine.queue", DISPATCH_QUEUE_SERIAL);
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
    dispatch_async(_eventQueue, ^{
        if (self.currentState == TJPConnectStateConnecting &&
            [event isEqualToString:TJPConnectEventConnect]) {
            TJPLOG_INFO(@"连接已在进行中，保持状态");
            return;
        }
        if (self.currentState == TJPConnectStateDisconnected && [event isEqualToString:TJPConnectEventDisconnect]) {
            TJPLOG_INFO(@"连接已断开，重复操作");
            return;
        }
        
        TJPLOG_INFO(@"发送事件 :%@", event);
        NSString *key = [NSString stringWithFormat:@"%@:%@", self.currentState, event];
        TJPLOG_INFO(@"查找转换规则的 key: %@", key);

        TJPConnectState newState = self->_transitions[key];
        TJPLOG_INFO(@"新状态为 :%@", newState);
        
        if (!newState) {
            TJPLOG_INFO(@"无效事件 当前状态:%@ ->状态事件:%@", self.currentState, event);
            return;
        }
        
        TJPConnectState oldState = self.currentState;
        self.currentState = newState;
        
        //状态变更回调
        for (void(^handler)(TJPConnectState, TJPConnectState) in self->_stateChangeHandlers) {
            handler(oldState, newState);
        }
    });
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
