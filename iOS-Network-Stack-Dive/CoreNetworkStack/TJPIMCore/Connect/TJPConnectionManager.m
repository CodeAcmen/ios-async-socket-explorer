//
//  TJPConnectionManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/15.
//

#import "TJPConnectionManager.h"
#import <GCDAsyncSocket.h>
#import "TJPNetworkDefine.h"
#import "TJPConnectStateMachine.h"


@interface TJPConnectionManager () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, copy) NSString *currentHost;
@property (nonatomic, assign) uint16_t currentPort;
@property (nonatomic, assign) TJPDisconnectReason disconnectReason;
@property (nonatomic, strong) dispatch_source_t connectionTimeoutTimer;
@property (nonatomic, assign) TJPConnectionState internalState;
@property (nonatomic, assign) uint8_t majorVersion;
@property (nonatomic, assign) uint8_t minorVersion;


@end

@implementation TJPConnectionManager

- (instancetype)initWithDelegateQueue:(dispatch_queue_t)delegateQueue {
    if (self = [super init]) {
        _socketQueue = delegateQueue ?: dispatch_queue_create("com.connectionManager.tjp.socketQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_socketQueue, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        _internalState = TJPConnectionStateDisconnected;
        _disconnectReason = TJPDisconnectReasonNone;
        _connectionTimeout = 30.0; // 默认超时时间
        _useTLS = NO; // 默认不使用TLS
        _majorVersion = kProtocolVersionMajor;
        _minorVersion = kProtocolVersionMinor;

    }
    return self;
}

- (void)dealloc {
    NSLog(@"🚨 [TJPConnectionManager] 开始释放 ConnectionManager");
    
    // 🔥 关键修复：立即清理 socket delegate，防止野指针回调
    if (self.socket) {
        NSLog(@"🚨 [TJPConnectionManager] 清理 socket delegate");
        
        // 在释放前先移除delegate，防止socket回调已释放的对象
        self.socket.delegate = nil;
        self.socket.delegateQueue = nil;
        
        // 强制断开socket连接
        [self.socket disconnect];
        self.socket = nil;
    }
    
    // 取消定时器
    [self cancelConnectionTimeoutTimer];
    
    NSLog(@"🚨 [TJPConnectionManager] ConnectionManager 释放完成");
}

#pragma mark - Properties
- (BOOL)isConnected {
    return self.internalState == TJPConnectionStateConnected;
}

- (BOOL)isConnecting {
    return self.internalState == TJPConnectionStateConnecting;
}

#pragma mark - State Management
- (void)setInternalState:(TJPConnectionState)newState {
    if (_internalState == newState) return;
    
    TJPConnectionState oldState = _internalState;
    _internalState = newState;
    
    TJPLOG_INFO(@"[TJPConnectionManager] 连接管理器状态变化: %d -> %d", (int)oldState, (int)newState);
    
    // 这里可以添加更复杂的状态监控和日志记录逻辑
}

#pragma mark - Public Methods
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    dispatch_async(self.socketQueue, ^{
        if (self.internalState != TJPConnectionStateDisconnected) {
            TJPLOG_INFO(@"[TJPConnectionManager] 当前已有连接或正在连接中，无法发起新连接");
            return;
        }
        
        if (host.length == 0) {
            TJPLOG_ERROR(@"[TJPConnectionManager] 主机地址不能为空,请检查!!");
            return;
        }
        
        self.currentHost = host;
        self.currentPort = port;
        self.disconnectReason = TJPDisconnectReasonNone;
        
        // 更新内部状态
        [self setInternalState:TJPConnectionStateConnecting];

        // 通知代理将要连接
        if ([self.delegate respondsToSelector:@selector(connectionWillConnect:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate connectionWillConnect:self];
            });
        }
        
        // 创建新的Socket实例
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
        
        // 执行连接操作
        NSError *error = nil;
        if (![self.socket connectToHost:host onPort:port error:&error]) {
            [self handleError:error withReason:TJPDisconnectReasonSocketError];
            return;
        }
        
        // 启动连接超时计时器
        [self startConnectionTimeoutTimer];
        
    });
}

- (void)disconnect {
    [self disconnectWithReason:TJPDisconnectReasonUserInitiated];
}

- (void)forceDisconnect {
    dispatch_async(self.socketQueue, ^{
        TJPLOG_INFO(@"[TJPConnectionManager] 连接管理器强制断开");
        // 立即关闭socket，不等待优雅断开
        if (self.socket) {
            [self.socket disconnect];
            self.socket = nil;
        }
        
        // 立即触发断开回调
        if (self.delegate && [self.delegate respondsToSelector:@selector(connection:didDisconnectWithError:reason:)]) {
            NSError *error = [NSError errorWithDomain:@"TJPConnectionManager"
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Force disconnect"}];
            [self.delegate connection:self didDisconnectWithError:error reason:TJPDisconnectReasonForceReconnect];
        }
    });
}

- (void)disconnectWithReason:(TJPDisconnectReason)reason {
    if (!self) {
        NSLog(@"[TJPConnectionManager] self 为 nil，直接返回");
        return;
    }
    // 打印调用栈，找出谁调用了这个方法
//    NSArray *callStack = [NSThread callStackSymbols];
//    NSLog(@"📞 [ConnectionManager] disconnect 调用栈:");
//    for (NSInteger i = 0; i < MIN(callStack.count, 8); i++) {
//        NSLog(@"📞 %ld: %@", (long)i, callStack[i]);
//    }
    
    dispatch_async(self.socketQueue, ^{
        if (!self) {
            NSLog(@"[TJPConnectionManager] 异步执行时 self 无效");
            return;
        }
        @try {
            if (self.internalState == TJPConnectionStateDisconnected) {
                NSLog(@"[TJPConnectionManager] 已经是断开状态，跳过");
                return;
            }
        } @catch (NSException *exception) {
            NSLog(@"[TJPConnectionManager] 访问 internalState 异常: %@", exception.reason);
            return;
        }
        
        
        [self cancelConnectionTimeoutTimer];
        self.disconnectReason = reason;
        
        // 更新内部状态
        [self setInternalState:TJPConnectionStateDisconnecting];
        
        // 通知代理将要断开
        if ([self.delegate respondsToSelector:@selector(connectionWillDisconnect:reason:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate connectionWillDisconnect:self reason:reason];
            });
        }
        if (self.socket) {
            [self.socket disconnect];
        }
    });
}

- (void)sendData:(NSData *)data {
    [self sendData:data withTimeout:-1 tag:0];
}

- (void)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    dispatch_async(self.socketQueue, ^{
        if (self.internalState != TJPConnectionStateConnected) {
            TJPLOG_WARN(@"[TJPConnectionManager] 当前未连接，无法发送数据");
            return;
        }
        
        [self.socket writeData:data withTimeout:timeout tag:tag];
    });
}

- (void)startTLS:(NSDictionary *)settings {
    dispatch_async(self.socketQueue, ^{
        if (self.internalState != TJPConnectionStateConnected) {
            TJPLOG_WARN(@"[TJPConnectionManager] 当前未连接，无法启动TLS");
            return;
        }
        
        [self.socket startTLS:settings ?: @{
            (NSString *)kCFStreamSSLPeerName: self.currentHost
        }];
    });
}

- (void)setVersionInfo:(uint8_t)majorVersion minorVersion:(uint8_t)minorVersion {
    dispatch_async(self.socketQueue, ^{
        self.majorVersion = majorVersion;
        self.minorVersion = minorVersion;
    });
}

#pragma mark - Private Methods
- (void)handleError:(NSError *)error withReason:(TJPDisconnectReason)reason {
    self.disconnectReason = reason;
    [self setInternalState:TJPConnectionStateDisconnected];
    
    if ([self.delegate respondsToSelector:@selector(connection:didDisconnectWithError:reason:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connection:self didDisconnectWithError:error reason:reason];
        });
    }
}

- (void)startConnectionTimeoutTimer {
    [self cancelConnectionTimeoutTimer];
    
    self.connectionTimeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.socketQueue);
    
    dispatch_source_set_timer(self.connectionTimeoutTimer,
                             dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.connectionTimeout * NSEC_PER_SEC)),
                             DISPATCH_TIME_FOREVER,
                             (1ull * NSEC_PER_SEC) / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.connectionTimeoutTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (strongSelf.internalState == TJPConnectionStateConnecting) {
            TJPLOG_ERROR(@"[TJPConnectionManager] 连接超时（%0.1f秒）", strongSelf.connectionTimeout);
            [strongSelf cancelConnectionTimeoutTimer];
            [strongSelf disconnectWithReason:TJPDisconnectReasonConnectionTimeout];
        }
    });
    
    dispatch_resume(self.connectionTimeoutTimer);
}

- (void)cancelConnectionTimeoutTimer {
    if (self.connectionTimeoutTimer) {
        dispatch_source_cancel(self.connectionTimeoutTimer);
        self.connectionTimeoutTimer = nil;
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self cancelConnectionTimeoutTimer];
    [self setInternalState:TJPConnectionStateConnected];
    
    if ([self.delegate respondsToSelector:@selector(connectionDidConnect:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidConnect:self];
        });
    }
    
    // 如果需要TLS，自动启动
    if (self.useTLS) {
        [self startTLS:nil];
    }
    
    // 开始读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if ([self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connection:self didReceiveData:data];
        });
    }
    
    // 继续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    TJPDisconnectReason reason = self.disconnectReason;
    
    // 如果没有明确设置断开原因，根据错误确定原因
    if (reason == TJPDisconnectReasonNone && err) {
        if ([err.domain isEqualToString:NSPOSIXErrorDomain]) {
            switch (err.code) {
                case ETIMEDOUT:
                    reason = TJPDisconnectReasonConnectionTimeout;
                    break;
                case ECONNREFUSED:
                    reason = TJPDisconnectReasonSocketError;
                    break;
                case ENETDOWN:
                case ENETUNREACH:
                    reason = TJPDisconnectReasonNetworkError;
                    break;
                default:
                    reason = TJPDisconnectReasonSocketError;
                    break;
            }
        } else if ([err.domain isEqualToString:NSURLErrorDomain]) {
            switch (err.code) {
                case NSURLErrorNotConnectedToInternet:
                case NSURLErrorNetworkConnectionLost:
                    reason = TJPDisconnectReasonNetworkError;
                    break;
                case NSURLErrorTimedOut:
                    reason = TJPDisconnectReasonConnectionTimeout;
                    break;
                default:
                    reason = TJPDisconnectReasonSocketError;
                    break;
            }
        } else {
            reason = TJPDisconnectReasonSocketError;
        }
    }
    
    self.disconnectReason = reason;
    [self setInternalState:TJPConnectionStateDisconnected];
    
    if ([self.delegate respondsToSelector:@selector(connection:didDisconnectWithError:reason:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connection:self didDisconnectWithError:err reason:reason];
        });
    }
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    if ([self.delegate respondsToSelector:@selector(connectionDidSecure:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidSecure:self];
        });
    }
}


@end
