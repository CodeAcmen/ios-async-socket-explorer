//
//  TJPReconnectPolicy.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPReconnectPolicy.h"
#import <Reachability/Reachability.h>

#import "TJPNetworkCoordinator.h"
#import "TJPNetworkDefine.h"


static const NSTimeInterval kMaxReconnectDelay = 30;


@interface TJPReconnectPolicy ()

@property (nonatomic, strong) dispatch_block_t currentRetryTask;

@end

@implementation TJPReconnectPolicy {
    //当前尝试次数
//    NSInteger _currentAttempt;
    //网络任务的QoS级别
    dispatch_qos_class_t _qosClass;
}

- (instancetype)initWithMaxAttempst:(NSInteger)attempts baseDelay:(NSTimeInterval)delay qos:(TJPNetworkQoS)qos delegate:(id<TJPReconnectPolicyDelegate>)delegate {
    if (self = [super init]) {
        _maxAttempts = attempts;
        _baseDelay = delay;
        _qosClass = [self qosClassFromEnum:qos];
        _delegate = delegate;
        _currentAttempt = 0;
    }
    return self;
}

- (dispatch_qos_class_t)qosClassFromEnum:(TJPNetworkQoS)qos {
    switch (qos) {
        case TJPNetworkQoSUserInitiated: return QOS_CLASS_USER_INITIATED;
        case TJPNetworkQoSBackground: return QOS_CLASS_BACKGROUND;
        default: return QOS_CLASS_DEFAULT;
    }
}

- (void)attemptConnectionWithBlock:(dispatch_block_t)connectionBlock {
    TJPLOG_INFO(@"开始连接尝试，当前尝试次数%ld/%ld", (long)_currentAttempt, (long)_maxAttempts);
    //如果超过最大重试次数 停止重试
    if (_currentAttempt >= _maxAttempts) {
        TJPLOG_ERROR(@"已达到最大重试次数%ld/%ld，停止重试", (long)_currentAttempt, (long)_maxAttempts);
        [self notifyReachMaxAttempts];
        return;
    }
    
    //指数退避+随机延迟的方式 避免服务器惊群效应
    NSTimeInterval delay = [self calculateDelay];

    //在指定的QoS级别的全局队列中调度重试任务
    dispatch_queue_t queue = dispatch_get_global_queue(_qosClass, 0);

   
    self.currentRetryTask = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, ^{
            // 检查网络是否真的可达
        if ([[TJPNetworkCoordinator shared].reachability currentReachabilityStatus] != NotReachable) {
                TJPLOG_INFO(@"网络状态可达，执行连接块");
                if (connectionBlock) connectionBlock();
                self->_currentAttempt++;
                TJPLOG_INFO(@"当前尝试次数更新为%ld", (long)self->_currentAttempt);
            } else {
                TJPLOG_INFO(@"网络不可达，跳过本次重连");
                // 网络不可达时延迟再次尝试
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), queue, ^{
                    [self attemptConnectionWithBlock:connectionBlock];
                });
            }
        });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, self.currentRetryTask);
    
}

- (NSTimeInterval)calculateDelay {
    //mock测试时 移除随机延迟
//    return MIN(pow(_baseDelay, _currentAttempt), kMaxReconnectDelay);
    //指数退避 + 随机延迟
    return MIN(pow(_baseDelay, _currentAttempt) + arc4random_uniform(3), kMaxReconnectDelay);
}

- (void)notifyReachMaxAttempts {
    TJPLOG_INFO(@"已达到最大重连次数: %ld", (long)_maxAttempts);
    if (self.delegate && [self.delegate respondsToSelector:@selector(reconnectPolicyDidReachMaxAttempts:)]) {
        [self.delegate reconnectPolicyDidReachMaxAttempts:self];
    }
}

- (void)stopRetrying {
    // 停止当前的重试任务
    if (self.currentRetryTask) {
        dispatch_block_cancel(self.currentRetryTask);
        self.currentRetryTask = nil;
        TJPLOG_INFO(@"停止当前重试任务");
    }
    
    TJPLOG_INFO(@"重试操作已停止");
}

- (void)reset {
    _currentAttempt = 0;
}


#pragma mark - 单元测试
- (dispatch_qos_class_t)qosClass {
    return _qosClass;
}


@end
