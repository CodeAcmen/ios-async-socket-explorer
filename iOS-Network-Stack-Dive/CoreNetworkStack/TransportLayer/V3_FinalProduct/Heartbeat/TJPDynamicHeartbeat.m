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

- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval seqManager:(nonnull TJPSequenceManager *)seqManager session:(id<TJPSessionProtocol>)session {
    if (self = [super init]) {
        _networkCondition = [[TJPNetworkCondition alloc] init];
        _sequenceManager = seqManager;
        _baseInterval = baseInterval;
        
        _session = session;
        
        // 初始化字典
        _pendingHeartbeats = [NSMutableDictionary dictionary];
        
        // 专用串行队列，低优先级
        _heartbeatQueue = dispatch_queue_create("com.tjp.dynamicHeartbeat.serialQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_heartbeatQueue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
       
        
        _maxRetryCount = 3;
    }
    return self;
}


- (void)startMonitoring {
    dispatch_async(self.heartbeatQueue, ^{
        // 如果定时器已存在，先停止当前的监控
        if (self->_heartbeatTimer) {
            TJPLOG_INFO(@"心跳监控已在运行，先停止当前监控");
            [self stopMonitoring];
        }
        
        //重置状态
        self.currentInterval = self.baseInterval;
        
        // 清空 pendingHeartbeats 字典
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
        //规则调整
        [self _calculateQualityLevel:condition];
        
        if (self->_heartbeatTimer == nil) {
            TJPLOG_ERROR(@"当前_heartbeatTimer定时器不存在,更新间隔失败,请检查!!!");
            return;
        }
        // 根据网络状态设置新间隔
        [self _updateTimerInterval];
    });
}

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
    
    //增加随机扰动 抗抖动设计  单元测试时需要注释
    CGFloat randomFactor = 0.9 + (arc4random_uniform(200) / 1000.0); //0.9 - 1.1
    _currentInterval *= randomFactor;
    
    //再设置硬性限制 防止出现夸张边界问题  15-300s
    _currentInterval = MIN(MAX(_currentInterval, 15), 300);
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


- (BOOL)isHeartbeatSequence:(uint32_t)sequence {
    // 判断序列号是否属于心跳类别
    return [self.sequenceManager isSequenceForCategory:sequence category:TJPMessageCategoryHeartbeat];
}



@end



