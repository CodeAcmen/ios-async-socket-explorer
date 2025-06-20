//
//  TJPDynamicHeartbeat.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPDynamicHeartbeat.h"
#import "TJPConcreteSession.h"
#import "TJPSessionProtocol.h"
#import "TJPNetworkCondition.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkDefine.h"
#import "TJPMessageBuilder.h"


@interface TJPDynamicHeartbeat ()
//@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;

@property (nonatomic, strong) dispatch_queue_t heartbeatQueue;

@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSInteger maxRetryCount;

@end

@implementation TJPDynamicHeartbeat {
    dispatch_source_t _heartbeatTimer;
    __weak id<TJPSessionProtocol> _session;
}

#pragma mark - Initialization
- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval seqManager:(nonnull TJPSequenceManager *)seqManager session:(id<TJPSessionProtocol>)session {
    if (self = [super init]) {
        // 初始化网络指标收集器
        _networkCondition = [[TJPNetworkCondition alloc] init];
        // 序列号管理器
        _sequenceManager = seqManager;
        
        _baseInterval = baseInterval;
        
        _session = session;
        
        // 初始化字典
        _pendingHeartbeats = [NSMutableDictionary dictionary];
        
        // 专用串行队列，低优先级
        _heartbeatQueue = dispatch_queue_create("com.tjp.dynamicHeartbeat.serialQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_heartbeatQueue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        
        // 最大重试次数
        _maxRetryCount = 3;
        
        // 初始化心跳模式配置
        [self initializeHeartbeatConfiguration];
        
        // 注册应用生命周期通知
        [self registerForAppLifecycleNotifications];

        // 初始为前台模式
        _heartbeatMode = TJPHeartbeatModeForeground;
        // 当前app状态为活跃
        _currentAppState = TJPAppStateActive;
        // 默认平衡策略
        _heartbeatStrategy = TJPHeartbeatStrategyBalanced;
        // 后台任务标志符
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        
        TJPLOG_INFO(@"心跳管理器已初始化，等待连接成功后自动启动");
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self endBackgroundTask];
}


#pragma mark - Configuration
- (void)initializeHeartbeatConfiguration {
    // 初始化各模式下的基础间隔（秒）
    _modeBaseIntervals = [NSMutableDictionary dictionary];
    [_modeBaseIntervals setObject:@(_baseInterval) forKey:@(TJPHeartbeatModeForeground)];
    [_modeBaseIntervals setObject:@(_baseInterval * 2.5) forKey:@(TJPHeartbeatModeBackground)];
    [_modeBaseIntervals setObject:@(_baseInterval * 4.0) forKey:@(TJPHeartbeatModeLowPower)];
    
    // 初始化各模式下的最小间隔（秒）
    _modeMinIntervals = [NSMutableDictionary dictionary];
    [_modeMinIntervals setObject:@(15.0) forKey:@(TJPHeartbeatModeForeground)];
    [_modeMinIntervals setObject:@(30.0) forKey:@(TJPHeartbeatModeBackground)];
    [_modeMinIntervals setObject:@(45.0) forKey:@(TJPHeartbeatModeLowPower)];
    
    // 初始化各模式下的最大间隔（秒）
    _modeMaxIntervals = [NSMutableDictionary dictionary];
    [_modeMaxIntervals setObject:@(300.0) forKey:@(TJPHeartbeatModeForeground)];   // 前台最大5分钟
    [_modeMaxIntervals setObject:@(600.0) forKey:@(TJPHeartbeatModeBackground)];   // 后台最大10分钟
    [_modeMaxIntervals setObject:@(900.0) forKey:@(TJPHeartbeatModeLowPower)];     // 低电量最大15分钟
}

- (void)registerForAppLifecycleNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // 应用进入前台
    [center addObserver:self selector:@selector(handleAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // 应用变为活跃
    [center addObserver:self selector:@selector(handleAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 应用将变为非活跃
    [center addObserver:self selector:@selector(handleAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    
    // 应用进入后台
    [center addObserver:self selector:@selector(handleAppDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // 应用将被终止
    [center addObserver:self selector:@selector(handleAppWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    
    // 低电量模式变化通知
    if (@available(iOS 9.0, *)) {
        [center addObserver:self selector:@selector(handleLowPowerModeChanged:) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    }
    
    // 内存警告通知
    [center addObserver:self selector:@selector(handleMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}



#pragma mark - Public Method
- (void)startMonitoring {
    dispatch_async(self.heartbeatQueue, ^{
        // 如果定时器已存在，先停止当前的监控
        if (self->_heartbeatTimer) {
            TJPLOG_INFO(@"心跳监控已在运行，先停止当前监控");
            [self stopMonitoring];
        }
        
        //重置状态
        self.currentInterval = self.baseInterval;
        
        //清空 pendingHeartbeats 字典
        [self.pendingHeartbeats removeAllObjects];
        
        TJPLOG_INFO(@"heartbeat 准备开始发送心跳");
        //发送心跳包
        [self sendHeartbeat];
        
        //获取旧定时器
        if (self->_heartbeatTimer) {
            dispatch_source_cancel(self->_heartbeatTimer);
            self->_heartbeatTimer = nil;
        }
        
        //创建心跳包定时器
        self->_heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.heartbeatQueue);
        //设置定时器的触发时间
        [self _updateTimerInterval];
        
        //设置定时器的事件处理顺序
        dispatch_source_set_event_handler(self->_heartbeatTimer, ^{
            [self sendHeartbeat];
        });
        //启动定时器
        dispatch_resume(self->_heartbeatTimer);
        
        TJPLOG_INFO(@"心跳监控已启动，基础间隔: %.1f秒", self.baseInterval);
    });
}

- (void)updateSession:(id<TJPSessionProtocol>)session {
    dispatch_async(self.heartbeatQueue, ^{
        self->_session = session;
        TJPLOG_INFO(@"心跳管理器更新 session 引用");
        
        // 同步状态检查
        if (session && [session.connectState isEqualToString:TJPConnectStateConnected]) {
            // 如果会话已连接但心跳未启动，则启动心跳
            if (!self->_heartbeatTimer) {
                TJPLOG_INFO(@"会话已连接但心跳未启动，自动启动心跳");
                [self startMonitoring];
            }
        } else {
            // 如果会话未连接但心跳已启动，则停止心跳
            if (self->_heartbeatTimer) {
                TJPLOG_INFO(@"会话未连接但心跳仍在运行，自动停止心跳");
                [self stopMonitoring];
            }
        }
    });
}


- (void)_updateTimerInterval {
    if (_heartbeatTimer) {
        uint64_t interval = (uint64_t)(_currentInterval * NSEC_PER_SEC);
        dispatch_source_set_timer(_heartbeatTimer,
                                dispatch_time(DISPATCH_TIME_NOW, interval),
                                interval,
                                1 * NSEC_PER_SEC);
        TJPLOG_INFO(@"心跳定时器间隔已更新为 %.1f 秒", _currentInterval);
    }
}

- (void)stopMonitoring {
    dispatch_async(self.heartbeatQueue, ^{
        if (self->_heartbeatTimer) {
            dispatch_source_cancel(self->_heartbeatTimer);
            self->_heartbeatTimer = nil;
        }
        [self.pendingHeartbeats removeAllObjects];
        self->_session = nil;
    });
}

- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition {
    dispatch_async(self.heartbeatQueue, ^{
        //增强检查：如果session未连接，直接跳过
        if (!self->_session || ![self->_session.connectState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_DEBUG(@"[TJPDynamicHeartbeat] 会话未连接，跳过心跳间隔调整");
            return;
        }
        // 增加空指针保护，避免日志被污染
        if (self->_heartbeatTimer == nil) {
            TJPLOG_DEBUG(@"[TJPDynamicHeartbeat] 心跳定时器未启动，跳过间隔调整");
            return;
        }
        // 规则调整
        [self _calculateQualityLevel:condition];
        
        // 根据网络状态设置新间隔
        [self _updateTimerInterval];
    });
}

- (void)sendHeartbeat {
    dispatch_async(self.heartbeatQueue, ^{
        id<TJPSessionProtocol> strongSession = self->_session;
        if (!strongSession) {
            TJPLOG_ERROR(@"动态心跳管理的session已被销毁");
            return;
        }
        if (![strongSession.connectState isEqualToString:TJPConnectStateConnected]) {
            TJPLOG_WARN(@"连接未就绪，当前连接状态为: %@", strongSession.connectState);
            [self sendHeartbeatFailed];
            return;
        }
        //重置重试计数
        self.retryCount = 0;
        
        //获取序列号
        uint32_t sequence = [self.sequenceManager nextSequenceForCategory:TJPMessageCategoryHeartbeat];
        
        TJPLOG_INFO(@"心跳包正在组装,准备发出  序列号为: %u", sequence);
        
        //组装心跳包
        NSData *packet = [self buildHeartbeatPacket:sequence];
        if (!packet) {
            TJPLOG_ERROR(@"心跳包构建失败，取消此次心跳");
            return;
        }
        
        //记录发送时间(毫秒级)
        NSDate *sendTime = [NSDate date];
        
        //log输出时间为转换后的北京时间
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8*3600]]; // 东八区
        NSString *beijingTime = [formatter stringFromDate:sendTime];

        
        //将心跳包的序列号和发送时间存入 pendingHeartbeats  使用 dispatch_barrier_async 来安全地更新字典
        dispatch_barrier_async(self.heartbeatQueue, ^{
            //将心跳包的序列号和发送时间存入 pendingHeartbeats
            [self.pendingHeartbeats setObject:sendTime forKey:@(sequence)];
        });
            
        //发送心跳包
        TJPLOG_INFO(@"heartbeatManager 准备将心跳包移交给 session 发送  当前北京时间:%@", beijingTime);
        [self->_session sendHeartbeat:packet];
        
        // 通过统一方法调整间隔
        [self adjustIntervalWithNetworkCondition:self.networkCondition];
        
        // 设置动态超时（3倍RTT或最低15秒）
        NSTimeInterval timeout = MAX(self.networkCondition.roundTripTime * 3 / 1000.0, 15);

        //超时检测
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            if (self.pendingHeartbeats[@(sequence)]) {
                TJPLOG_INFO(@"触发序列号 %u 的心跳超时检测", sequence);
                [self handleHeaderbeatTimeoutForSequence:sequence];
            }
        });
    });
}

- (void)sendHeartbeatFailed {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_ERROR(@"心跳发送失败,准备重试");
        id<TJPSessionProtocol> strongSession = self->_session;
        if (!strongSession) {
            return;
        }
        
        // 先增加重试计数，再进行判断
        self.retryCount++;
        
        TJPLOG_INFO(@"当前重试次数: %ld/%ld", (long)self.retryCount, (long)self.maxRetryCount);


        if (self.retryCount >= self.maxRetryCount) {
            TJPLOG_ERROR(@"心跳连续失败 %ld 次，触发会话重建", (long)self.maxRetryCount);
            [strongSession forceReconnect];
            self.retryCount = 0;
            return;
        }
        
        // 指数退避重试（2^retryCount 秒）
        NSTimeInterval delay = pow(2, self.retryCount - 1);  // 1s 2s 4s 8s
        
        TJPLOG_INFO(@"安排在 %.1f 秒后进行第 %ld 次重试", delay, (long)self.retryCount);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            [self sendHeartbeat];
        });
    });
}

- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence {
    dispatch_async(self.heartbeatQueue, ^{
        NSDate *sendTime = self.pendingHeartbeats[@(sequence)];
        
        if (!sendTime) {
            TJPLOG_INFO(@"收到未知心跳包的ACK，序列号: %u", sequence);
            return;
        }
        
        TJPLOG_INFO(@"接收到 心跳ACK 数据包并进行处理");
        //计算RTT并更新网络状态
        NSTimeInterval rtt = [[NSDate date] timeIntervalSinceDate:sendTime] * 1000; //转毫秒

        //更新网络状况
        [self.networkCondition updateRTTWithSample:rtt];
        [self.networkCondition updateLostWithSample:NO];


        //收到ACK后主动调整间隔
        [self adjustIntervalWithNetworkCondition:self.networkCondition];

        //移除已确认心跳，避免超时逻辑误触发
        [self _removeHeartbeatsForSequence:sequence];
    });
}

// 心跳超时处理 - 使用通知解耦
- (void)handleHeaderbeatTimeoutForSequence:(uint32_t)sequence {
    dispatch_async(self.heartbeatQueue, ^{
        if (self.pendingHeartbeats[@(sequence)]) {
            TJPLOG_INFO(@"序列号为: %u的心跳包超时未确认  心跳丢失", sequence);
            
            // 更新丢包率
            [self.networkCondition updateLostWithSample:YES];
            
            // 触发动态调整
            [self adjustIntervalWithNetworkCondition:self.networkCondition];
            
            // 发送通知而不是直接操作session
            [[NSNotificationCenter defaultCenter] postNotificationName:kHeartbeatTimeoutNotification
                                                              object:self
                                                            userInfo:@{@"session": self->_session}];
            
            // 移除超时的心跳
            [self _removeHeartbeatsForSequence:sequence];
        }
    });
}

- (BOOL)isHeartbeatSequence:(uint32_t)sequence {
    // 判断序列号是否属于心跳类别
    return [self.sequenceManager isSequenceForCategory:sequence category:TJPMessageCategoryHeartbeat];
}



- (void)configureWithBaseInterval:(NSTimeInterval)baseInterval  minInterval:(NSTimeInterval)minInterval maxInterval:(NSTimeInterval)maxInterval forMode:(TJPHeartbeatMode)mode {
    dispatch_async(self.heartbeatQueue, ^{
        self.modeBaseIntervals[@(mode)] = @(baseInterval);
        self.modeMinIntervals[@(mode)] = @(minInterval);
        self.modeMaxIntervals[@(mode)] = @(maxInterval);
        
        TJPLOG_INFO(@"已配置模式 %lu：base=%.1fs, min=%.1fs, max=%.1fs", (unsigned long)mode, baseInterval, minInterval, maxInterval);
        
        // 如果是当前模式，立即应用新配置
        if (self.heartbeatMode == mode) {
            self.baseInterval = baseInterval;
            [self adjustIntervalWithNetworkCondition:self.networkCondition];
        }
    });
}


- (void)setHeartbeatMode:(TJPHeartbeatMode)mode force:(BOOL)force {
    dispatch_async(self.heartbeatQueue, ^{
        if (force || [self canSwitchToMode:mode]) {
            [self changeToHeartbeatMode:mode];
        } else {
            TJPLOG_WARN(@"当前应用状态不适合切换至模式: %lu", (unsigned long)mode);
        }
    });
}

#pragma mark - Notification Method
- (void)handleAppWillEnterForeground:(NSNotification *)notifacation {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"应用即将进入前台，准备心跳模式转换");
        
        self.currentAppState = TJPAppStateActive;
        self.isTransitioning = YES;
        self.lastModeChangeTime = [[NSDate date] timeIntervalSince1970];
        
        // 立即发送一次心跳确认当前状态
        [self sendHeartbeat];
        
        TJPLOG_INFO(@"已发送立即心跳以检测连接状态");
    });
}

- (void)handleAppDidBecomeActive:(NSNotification *)notification {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"应用已变为活跃状态，切换到前台心跳模式");
        // 改变心跳模式
        [self changeToHeartbeatMode:TJPHeartbeatModeForeground];
        
        // 结束后台任务
        [self endBackgroundTask];

        // 延迟解除过渡状态
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            self.isTransitioning = NO;
        });
        
        TJPLOG_INFO(@"已切换到前台心跳模式，当前间隔为 %.1f 秒", self.currentInterval);
    });
}

- (void)handleAppWillResignActive:(NSNotification *)notification {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"应用即将变为非活跃状态");
        // 此阶段通常无需调整心跳，等待可能的后台状态
        self.currentAppState = TJPAppStateInactive;
    });
}

- (void)handleAppDidEnterBackground:(NSNotification *)notification {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"应用已进入后台状态，切换到后台心跳模式");
        
        self.currentAppState = TJPAppStateBackground;
        self.backgroundTransitionCounter++;
        self.lastModeChangeTime = [[NSDate date] timeIntervalSince1970];
        
        // 开始后台任务以确保有足够时间完成心跳调整
        [self beginBackgroundTask];
        
        // 切换到后台模式
        [self changeToHeartbeatMode:TJPHeartbeatModeBackground];
        
        // 此时心跳间隔已经调整为后台模式的间隔，约为90秒左右
        TJPLOG_INFO(@"已切换到后台心跳模式，当前间隔为 %.1f 秒", self.currentInterval);
    });
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_INFO(@"应用即将终止");
        
        self.currentAppState = TJPAppStateTerminated;
        
        // 应用将被杀死，停止心跳
        [self stopMonitoring];
        
        // 结束后台任务
        [self endBackgroundTask];
    });
}

- (void)handleLowPowerModeChanged:(NSNotification *)notification {
    if (@available(iOS 9.0, *)) {
        dispatch_async(self.heartbeatQueue, ^{
            BOOL isLowPowerModeEnabled = [NSProcessInfo processInfo].lowPowerModeEnabled;
            
            if (isLowPowerModeEnabled) {
                TJPLOG_INFO(@"设备进入低电量模式，调整心跳策略");
                [self changeToHeartbeatMode:TJPHeartbeatModeLowPower];
            } else {
                TJPLOG_INFO(@"设备退出低电量模式，恢复正常心跳策略");
                
                // 根据应用当前状态决定心跳模式
                TJPHeartbeatMode newMode = (self.currentAppState == TJPAppStateBackground) ? TJPHeartbeatModeBackground : TJPHeartbeatModeForeground;
                
                [self changeToHeartbeatMode:newMode];
            }
        });
    }
}

- (void)handleMemoryWarning:(NSNotification *)notification {
    dispatch_async(self.heartbeatQueue, ^{
        TJPLOG_WARN(@"收到内存警告，临时调整心跳策略");
        
        // 暂时提高心跳间隔以减少资源消耗
        self.currentInterval = MIN(self.currentInterval * 1.5, [self.modeMaxIntervals[@(self.heartbeatMode)] doubleValue]);
        
        if (self->_heartbeatTimer) {
            [self _updateTimerInterval];
        }
        
        // 30秒后恢复正常策略
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            // 重新计算心跳间隔
            [self adjustIntervalWithNetworkCondition:self.networkCondition];
        });
    });
}



#pragma mark - Private Method
- (void)_calculateQualityLevel:(TJPNetworkCondition *)condition {
    if (condition.qualityLevel == TJPNetworkQualityPoor) {
        //恶劣网络大幅降低
        _currentInterval = _baseInterval * 2.5;
    }else if (condition.qualityLevel == TJPNetworkQualityFair || condition.qualityLevel == TJPNetworkQualityUnknown) {
        //未知网络&&网络不佳时降低频率
        _currentInterval = _baseInterval * 1.5;
    }else {
        //基于滑动窗口动态调整
        CGFloat rttFactor = condition.roundTripTime / 200.0;
        _currentInterval = _baseInterval * MAX(rttFactor, 1.0);
    }
    
    //基于心跳模式应用策略调整
    switch (self.heartbeatStrategy) {
        case TJPHeartbeatStrategyAggressive:
            // 激进策略，更频繁的心跳
            _currentInterval *= 0.8;
            break;
        case TJPHeartbeatStrategyConservative:
            // 保守策略，更节省的心跳
            _currentInterval *= 1.2;
            break;
        case TJPHeartbeatStrategyBalanced:
        default:
            // 平衡策略，不做额外调整
            break;
    }
    
    //处于过渡状态时 适当减小间隔
    if (self.isTransitioning) {
        _currentInterval = MIN(_currentInterval, [self.modeMinIntervals[@(self.heartbeatMode)] doubleValue] * 1.5);
    }
    
    //增加随机扰动 抗抖动设计  单元测试时需要注释
    CGFloat randomFactor = 0.9 + (arc4random_uniform(200) / 1000.0); //0.9 - 1.1
    _currentInterval *= randomFactor;
    
    // 应用模式特定的限制
    NSNumber *minIntervalObj = self.modeMinIntervals[@(self.heartbeatMode)];
    NSNumber *maxIntervalObj = self.modeMaxIntervals[@(self.heartbeatMode)];
    
    NSTimeInterval minInterval = minIntervalObj ? [minIntervalObj doubleValue] : 15.0;
    NSTimeInterval maxInterval = maxIntervalObj ? [maxIntervalObj doubleValue] : 300.0;
        
    
    //再设置硬性限制 防止出现夸张边界问题  15-300s
    _currentInterval = MIN(MAX(_currentInterval, minInterval), maxInterval);
}

- (void)_removeHeartbeatsForSequence:(uint32_t)sequence {
    dispatch_barrier_async(self.heartbeatQueue, ^{
        if (!sequence) return;
        [self.pendingHeartbeats removeObjectForKey:@(sequence)];
    });
}

- (NSData *)buildHeartbeatPacket:(uint32_t)sequence {
    NSData *emptyPayload = [NSData data]; // 心跳包通常没有负载

    NSString *sessionID = _session.sessionId;

    // 使用TJPMessageBuilder统一构建心跳包
    NSData *packet = [TJPMessageBuilder buildPacketWithMessageType:TJPMessageTypeHeartbeat
                                                         sequence:sequence
                                                          payload:emptyPayload
                                                      encryptType:TJPEncryptTypeNone
                                                     compressType:TJPCompressTypeNone
                                                        sessionID:sessionID];

    
    if (!packet) {
        TJPLOG_ERROR(@"心跳包构建失败");
        return nil;
    }

    return packet;
}


- (void)changeToHeartbeatMode:(TJPHeartbeatMode)newMode {
    dispatch_async(self.heartbeatQueue, ^{
        if (newMode == self.heartbeatMode) {
            return;
        }
        
        TJPLOG_INFO(@"心跳模式切换: %lu -> %lu", (unsigned long)self.heartbeatMode, (unsigned long)newMode);

        // 分别记录旧模式和新模式
        TJPHeartbeatMode oldMode = self.heartbeatMode;
        self.heartbeatMode = newMode;
        
        // 记录模式变更事件
        self.lastModeChangeTime = [[NSDate date] timeIntervalSince1970];
        
        // 如果新模式为暂停,需要停止定时器
        if (newMode == TJPHeartbeatModeSuspended) {
            if (self->_heartbeatTimer) {
                dispatch_source_cancel(self->_heartbeatTimer);
                self->_heartbeatTimer = nil;
                
                TJPLOG_INFO(@"心跳已暂停");
            }
            return;
        }
        
        //读取配置中新模式的基础心跳频率
        NSNumber *intervalObj = self.modeBaseIntervals[@(newMode)];
        if (!intervalObj) {
            TJPLOG_ERROR(@"未找到模式 %lu 的基础间隔配置，使用默认值", (unsigned long)newMode);
            intervalObj = @(self.baseInterval);
        }
        
        //更新基础间隔
        self.baseInterval = [intervalObj doubleValue];
        TJPLOG_INFO(@"心跳基础间隔更新: %.1f -> %.1f 秒", self.baseInterval, [intervalObj doubleValue]);
        
        // 发送模式变更通知
        [[NSNotificationCenter defaultCenter] postNotificationName:kHeartbeatModeChangedNotification object:self userInfo:@{
            @"oldMode": @(oldMode),
            @"newMode": @(newMode)
        }];
        
        
        // 记录埋点事件
//        [[TJPMetricsCollector sharedInstance] addEvent:TJPMetricsEventHeartbeatModeChanged
//                                           parameters:@{@"oldMode": @(oldMode), @"newMode": @(newMode)}];

        //更新当前模式下心跳频率
        [self adjustIntervalWithNetworkCondition:self.networkCondition];
        
        // 如果心跳定时器未启动但需要启动，则启动
        if (!self->_heartbeatTimer && newMode != TJPHeartbeatModeSuspended) {
            TJPLOG_INFO(@"启动心跳定时器");
            [self startMonitoring];
        }
    });
}

- (void)setHeartbeatStrategy:(TJPHeartbeatStrategy)heartbeatStrategy {
    dispatch_async(self.heartbeatQueue, ^{
        if (self.heartbeatStrategy == heartbeatStrategy) {
            return;
        }
        
        TJPLOG_INFO(@"心跳策略变更: %lu -> %lu", (unsigned long)self.heartbeatStrategy, (unsigned long)heartbeatStrategy);
        
        self.heartbeatStrategy = heartbeatStrategy;
        
        // 立即应用新策略
        [self adjustIntervalWithNetworkCondition:self.networkCondition];

    });
}



- (BOOL)canSwitchToMode:(TJPHeartbeatMode)mode {
    switch (mode) {
        case TJPHeartbeatModeForeground:
            return self.currentAppState == TJPAppStateActive;
            
        case TJPHeartbeatModeBackground:
            return self.currentAppState == TJPAppStateBackground || self.currentAppState == TJPAppStateInactive;
            
        case TJPHeartbeatModeLowPower:
            if (@available(iOS 9.0, *)) {
                return [NSProcessInfo processInfo].lowPowerModeEnabled;
            }
            return NO;
            
        case TJPHeartbeatModeSuspended:
            // 暂停模式随时可切换
            return YES;
            
        default:
            return NO;
    }
}

- (NSDictionary *)getHeartbeatStatus {
    __block NSDictionary *status;
    
    dispatch_sync(self.heartbeatQueue, ^{
        status = @{
            @"currentMode": @(self.heartbeatMode),
            @"currentStrategy": @(self.heartbeatStrategy),
            @"appState": @(self.currentAppState),
            @"baseInterval": @(self.baseInterval),
            @"currentInterval": @(self.currentInterval),
            @"pendingHeartbeats": @(self.pendingHeartbeats.count),
            @"networkQuality": @(self.networkCondition.qualityLevel),
            @"roundTripTime": @(self.networkCondition.roundTripTime),
            @"packetLossRate": @(self.networkCondition.packetLossRate),
            @"lastModeChangeTime": @(self.lastModeChangeTime),
            @"isTransitioning": @(self.isTransitioning),
            @"backgroundTransitions": @(self.backgroundTransitionCounter)
        };
    });
    
    return status;
}

#pragma mark - Background Task
- (void)beginBackgroundTask {
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        //当前应用进入后台任务模式
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
    }
    
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(self.heartbeatQueue, ^{
            TJPLOG_WARN(@"后台执行时间即将耗尽，调整心跳策略");
            
            // 记录埋点事件
//            [[TJPMetricsCollector sharedInstance] addEvent:@"heartbeat_background_expiring" parameters:nil];

            // 获取当前模式的最大间隔
            NSNumber *maxIntervalObj = self.modeMaxIntervals[@(self.heartbeatMode)];
            NSTimeInterval maxInterval = maxIntervalObj ? [maxIntervalObj doubleValue] : 600.0;

            
            // 设置为最大间隔以最大程度节约资源
            self.currentInterval = maxInterval;
            if (self->_heartbeatTimer) {
                [self _updateTimerInterval];
            }
            
            // 结束后台任务
            [self endBackgroundTask];
            
        });
    }];
}

- (void)endBackgroundTask {
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        
        TJPLOG_INFO(@"结束后台任务");
    }
}




@end



