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
TJPConnectEvent const TJPConnectEventConnectFailure = @"ConnectFailure";                //连接错误事件
TJPConnectEvent const TJPConnectEventNetworkError = @"NetworkError";                    //网络错误事件
TJPConnectEvent const TJPConnectEventDisconnect = @"Disconnect";                        //断开连接事件
TJPConnectEvent const TJPConnectEventDisconnectComplete = @"DisconnectComplete";        //断开完成事件
TJPConnectEvent const TJPConnectEventForceDisconnect = @"ForceDisconnect";              //强制断开事件
TJPConnectEvent const TJPConnectEventReconnect = @"Reconnect";                          //重新连接事件

@interface TJPConnectStateMachine ()
@property (nonatomic, assign, readwrite) BOOL isInitializing;
@property (nonatomic, assign, readwrite) BOOL hasSetInvalidHandler;


@property (nonatomic, readwrite) TJPConnectState currentState;
@property (nonatomic, copy, nullable) void (^invalidTransitionHandler)(TJPConnectState, TJPConnectEvent);


@end

@implementation TJPConnectStateMachine {
    dispatch_queue_t _eventQueue;
    NSMutableDictionary<NSString *, TJPConnectState> *_transitions;
    NSMutableArray<void (^)(TJPConnectState, TJPConnectState)> *_stateChangeHandlers;
}

#pragma mark - Initialization
- (instancetype)initWithInitialState:(TJPConnectState)initialState {
    return [self initWithInitialState:initialState setupStandardRules:NO];
}

- (instancetype)initWithInitialState:(TJPConnectState)initialState
                   setupStandardRules:(BOOL)autoSetup {
    if (self = [super init]) {
        TJPLOG_INFO(@"[TJPConnectStateMachine] 开始初始化状态机,临时禁用指标收集");
        // 初始化状态
        _isInitializing = YES;
        _hasSetInvalidHandler = NO;
        // 初始化直接设置ivar
        _currentState = [initialState copy];
        
        _transitions = [NSMutableDictionary dictionary];
        _stateChangeHandlers = [NSMutableArray array];
        _eventQueue = dispatch_queue_create("com.statemachine.queue", DISPATCH_QUEUE_SERIAL);
        
        if (autoSetup) {
            [self setupStandardTransitions];
        }
        
        TJPLOG_INFO(@"[TJPConnectStateMachine] 基础初始化完成，准备启动指标收集");
        
        // 异步启动指标收集 通过 setter 设置初始状态，触发 swizzled setCurrentState:
        __weak typeof(self) weakSelf = self;
        dispatch_async(_eventQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isInitializing = NO;

            // 通过 setter 重新设置状态，这次会被指标收集捕获
            strongSelf.currentState = initialState;
            
            TJPLOG_INFO(@"[TJPConnectStateMachine] 状态机初始化完成，指标收集已启动");
        });

    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
}

#pragma mark - Public Methods

- (void)addTransitionFromState:(TJPConnectState)fromState
                       toState:(TJPConnectState)toState
                      forEvent:(TJPConnectEvent)event {
    if (![self validateTransitionFromState:fromState toState:toState forEvent:event]) {
        return;
    }
    
    NSString *key = [NSString stringWithFormat:@"%@:%@", fromState, event];
    _transitions[key] = toState;
}

- (void)sendEvent:(TJPConnectEvent)event {
    dispatch_async(_eventQueue, ^{
        // 检查当前状态和事件是否有效
        if (![self canHandleEvent:event]) {
            TJPLOG_ERROR(@"[TJPConnectStateMachine] 无效状态转换: %@ -> %@", self.currentState, event);
            
            // 调用无效转换处理器
            if (self.invalidTransitionHandler) {
                self.invalidTransitionHandler(self.currentState, event);
            }
            return;
        }
        
        // 查找转换规则
        NSString *key = [NSString stringWithFormat:@"%@:%@", self.currentState, event];
        TJPConnectState newState = self->_transitions[key];
        
        if (!newState) {
            TJPLOG_INFO(@"[TJPConnectStateMachine] 无效事件 当前状态:%@ -> 状态事件:%@", self.currentState, event);
            return;
        }
        
        // 如果新状态与当前状态相同，可以考虑跳过或仅记录日志
        if ([newState isEqualToString:self.currentState]) {
            TJPLOG_INFO(@"[TJPConnectStateMachine] 状态保持不变: %@ (事件: %@)", self.currentState, event);
            return;
        }
        
        TJPConnectState oldState = self.currentState;
        self.currentState = newState;
        
        TJPLOG_INFO(@"[TJPConnectStateMachine] 状态转换: %@ -> %@ (事件: %@)", oldState, newState, event);
        
        // 状态变更回调
        for (void(^handler)(TJPConnectState, TJPConnectState) in self->_stateChangeHandlers) {
            handler(oldState, newState);
        }
    });
}

- (void)forceState:(TJPConnectState)state {
    dispatch_async(_eventQueue, ^{
        TJPConnectState oldState = self.currentState;
        self.currentState = state;
        
        TJPLOG_INFO(@"[TJPConnectStateMachine] 状态强制切换: %@ -> %@", oldState, state);
        
        // 通知状态变更
        for (void(^handler)(TJPConnectState, TJPConnectState) in self->_stateChangeHandlers) {
            handler(oldState, state);
        }
    });
}

- (void)onStateChange:(void (^)(TJPConnectState, TJPConnectState))handler {
    dispatch_async(_eventQueue, ^{
        [self->_stateChangeHandlers addObject:handler];
    });
}

- (void)setInvalidTransitionHandler:(void (^)(TJPConnectState, TJPConnectEvent))handler {
    TJPLOG_INFO(@"[TJPConnectStateMachine] 设置 InvalidTransitionHandler");
    
    if (self.hasSetInvalidHandler && handler != nil) {
        TJPLOG_INFO(@"[TJPConnectStateMachine] handler已设置，跳过重复设置");
        return;
    }

    dispatch_async(_eventQueue, ^{
        self.invalidTransitionHandler = handler;
        self.hasSetInvalidHandler = (handler != nil);
        TJPLOG_INFO(@"[TJPConnectStateMachine] InvalidTransitionHandler 设置完成，状态: %@",
              self.hasSetInvalidHandler ? @"已设置" : @"已清除");

    });
}

- (BOOL)canHandleEvent:(TJPConnectEvent)event {
    NSString *key = [NSString stringWithFormat:@"%@:%@", _currentState, event];
    return _transitions[key] != nil;
}

- (void)logAllTransitions {
    dispatch_sync(_eventQueue, ^{
        TJPLOG_INFO(@"[TJPConnectStateMachine] 当前状态转换表：");
        for (NSString *key in self->_transitions) {
            TJPLOG_INFO(@"%@ -> %@", key, self->_transitions[key]);
        }
    });
}

#pragma mark - Private Methods

- (BOOL)validateTransitionFromState:(TJPConnectState)fromState
                           toState:(TJPConnectState)toState
                          forEvent:(TJPConnectEvent)event {
    // 示例：禁止从 Connected 直接到 Connecting（原本应该是通过 Connect 事件触发）
    if ([fromState isEqualToString:TJPConnectStateConnected] &&
        [toState isEqualToString:TJPConnectStateConnecting] &&
        [event isEqualToString:TJPConnectEventConnect]) {
        TJPLOG_ERROR(@"[TJPConnectStateMachine] 禁止从 Connected 直接到 Connecting");
        return NO;
    }
    return YES;
}

- (BOOL)isValidTransitionFrom:(TJPConnectState)fromState
                           to:(TJPConnectState)toState
                     forEvent:(TJPConnectEvent)event {
    NSString *key = [NSString stringWithFormat:@"%@:%@", fromState, event];
    TJPConnectState expectedToState = _transitions[key];
    return [expectedToState isEqualToString:toState];
}

#pragma mark - Standard Transitions Setup

- (void)setupStandardTransitions {
    // 增加强制断开规则：允许从任何状态直接进入 Disconnected
    [self addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [self addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventForceDisconnect];
    
    // 状态保留规则
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];
    
    // 网络错误
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventNetworkError];
    [self addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventNetworkError];
    
    // 基本状态流转规则
    // 未连接->连接中 连接事件
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    
    // 重连事件（新增）
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventReconnect];
    
    // 连接中->已连接 连接成功事件
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    
    // 连接中->未连接 连接失败事件
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailure];
    [self addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailure];
    
    // 已连接->断开中 断开连接事件
    [self addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    [self addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    
    // 断开中->未连接 断开完成事件
    [self addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];
}

@end
