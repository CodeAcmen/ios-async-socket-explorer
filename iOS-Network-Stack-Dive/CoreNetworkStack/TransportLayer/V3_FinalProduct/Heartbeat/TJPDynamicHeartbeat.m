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
#import "JZNetworkDefine.h"


@interface TJPDynamicHeartbeat ()

@property (nonatomic, strong) NSDate *lastHeartbeatTime;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;


@end

@implementation TJPDynamicHeartbeat {
    dispatch_source_t _heartbeatTimer;
    __weak id<TJPSessionProtocol> _session;

}

- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval {
    if (self = [super init]) {
        _sequenceManager = [TJPSequenceManager new];
        _baseInterval = baseInterval;

    }
    return self;
}


- (void)startMonitoringForSession:(id<TJPSessionProtocol>)session {
    _session = session;
    _currentInterval = _baseInterval;
    
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    _heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    dispatch_source_set_timer(_heartbeatTimer, DISPATCH_TIME_NOW, _currentInterval * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_heartbeatTimer, ^{
        [self sendHeartbeat];
    });
    dispatch_resume(_heartbeatTimer);
}

- (void)stopMonitoring {
    
}

- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition {
    // 基础调整规则
    switch (condition.qualityLevel) {
        case TJPNetworkQualityExcellent:
            _currentInterval = _baseInterval * 0.8; // 良好网络加速心跳
            break;
        case TJPNetworkQualityGood:
            _currentInterval = _baseInterval;
            break;
        case TJPNetworkQualityFair:
            _currentInterval = _baseInterval * 1.5; // 网络不佳时降低频率
            break;
        case TJPNetworkQualityPoor:
            _currentInterval = _baseInterval * 2.0; // 恶劣网络大幅降低
            break;
    }
    
    // 拥塞时特殊处理
    if (condition.isCongested) {
        _currentInterval = MAX(_currentInterval, 60); // 最低60秒一次
    }
    
    // 新间隔
    dispatch_source_set_timer(_heartbeatTimer, DISPATCH_TIME_NOW, _currentInterval * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
}

- (void)sendHeartbeat {
    //组装心跳包
    NSData *packet = [self buildHeartbeatPacket];
    
    //记录发送时间
    uint32_t sequence = [self.sequenceManager currentSequence];
    self.lastHeartbeatTime = [NSDate date];
    //发送心跳包
    [_session sendData:packet];
    
    //超时检测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.currentInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.pendingHeartbeats[@(sequence)]) {
            [self handleHeaderbeatTimeoutForSequence:sequence];
        }
    });
}

- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence {
    [self.pendingHeartbeats removeObjectForKey:@(sequence)];
    
}

- (NSData *)buildHeartbeatPacket {
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeHeartbeat);
    //携带序列号
    header.sequence = htonl([self.sequenceManager nextSequence]);
    
    NSData *packet = [NSData dataWithBytes:&header length:sizeof(header)];
    return packet;
    
}

- (void)handleHeaderbeatTimeoutForSequence:(uint32_t)sequence {
    if (self.pendingHeartbeats[@(sequence)]) {
        TJPLOG_INFO(@"心跳包 %u 超时未确认", sequence);
        [_session disconnectWithReason:TJPDisconnectReasonHeartbeatTimeout];
    }
}


- (NSMutableDictionary<NSNumber *,NSDate *> *)pendingHeartbeats {
    if (!_pendingHeartbeats) {
        _pendingHeartbeats = [NSMutableDictionary dictionary];
    }
    return _pendingHeartbeats;
}



@end
