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
        
        // 专用串行队列，低优先级
        _heartbeatQueue = dispatch_queue_create("com.tjp.dynamicHeartbeat.serialQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_heartbeatQueue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
       
        
        _maxRetryCount = 3;
    }
    return self;
}


- (void)startMonitoring {
    //重置状态
    _currentInterval = _baseInterval;
    [_pendingHeartbeats removeAllObjects];

    
    TJPLOG_INFO(@"heartbeat 准备开始发送心跳");
    //发送心跳包
    [self sendHeartbeat];
    
    //获取旧定时器
    if (_heartbeatTimer) {
        dispatch_source_cancel(_heartbeatTimer);
        _heartbeatTimer = nil;
    }
    
    //创建心跳包定时器
    _heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.heartbeatQueue);
    //设置定时器的触发时间
    [self _updateTimerInterval];
    
    //设置定时器的事件处理顺序
    dispatch_source_set_event_handler(_heartbeatTimer, ^{
        [self sendHeartbeat];
    });
    //启动定时器
    dispatch_resume(_heartbeatTimer);
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
        uint32_t sequence = [self.sequenceManager nextSequence];
        
        TJPLOG_INFO(@"心跳包正在组装,准备发出  序列号为: %u", sequence);
        
        //组装心跳包
        NSData *packet = [self buildHeartbeatPacket:sequence];
//        TJPLOG_INFO(@"心跳包组装完成  序列号为: %u", sequence);
        
        //记录发送时间(毫秒级)
        NSDate *sendTime = [NSDate date];
        
        //log输出时间为转换后的北京时间
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8*3600]]; // 东八区
        NSString *beijingTime = [formatter stringFromDate:sendTime];

        
        //将心跳包的序列号和发送时间存入 pendingHeartbeats
        [self.pendingHeartbeats setObject:sendTime forKey:@(sequence)];
            
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
                [self _removeHeartbeatsForSequence:sequence];
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

        if (self.retryCount >= self.maxRetryCount) {
            TJPLOG_ERROR(@"心跳连续失败 %ld 次，触发会话重建", (long)self.maxRetryCount);
            [strongSession forceReconnect];
            self.retryCount = 0;
            return;
        }
        
        // 指数退避重试（3^retryCount 秒）
        NSTimeInterval delay = pow(3, self.retryCount);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.heartbeatQueue, ^{
            [self sendHeartbeat];
            self.retryCount++;
        });
    });
}

- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence {
    dispatch_async(self.heartbeatQueue, ^{
        NSDate *sendTime = self.pendingHeartbeats[@(sequence)];
        if (sendTime) {
            // 立即移除待处理心跳，避免超时逻辑误触发
            [self _removeHeartbeatsForSequence:sequence];
            
            //计算RTT并更新网络状态
            NSTimeInterval rtt = [[NSDate date] timeIntervalSinceDate:sendTime] * 1000; //转毫秒
            [self.networkCondition updateRTTWithSample:rtt];
            [self.networkCondition updateLostWithSample:NO];
            // 收到ACK后主动调整间隔
            [self adjustIntervalWithNetworkCondition:self.networkCondition];
        }
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
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeHeartbeat);
    //携带序列号
    header.sequence = htonl(sequence);
    
    NSData *packet = [NSData dataWithBytes:&header length:sizeof(header)];
    return packet;
}


- (NSMutableDictionary<NSNumber *,NSDate *> *)pendingHeartbeats {
    if (!_pendingHeartbeats) {
        _pendingHeartbeats = [NSMutableDictionary dictionary];
    }
    return _pendingHeartbeats;
}



@end
