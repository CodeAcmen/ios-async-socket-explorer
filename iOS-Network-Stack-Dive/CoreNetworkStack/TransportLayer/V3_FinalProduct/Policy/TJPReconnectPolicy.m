//
//  TJPReconnectPolicy.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPReconnectPolicy.h"
#import "TJPNetworkCoordinator.h"

static const NSTimeInterval kMaxReconnectDelay = 30;


@interface TJPReconnectPolicy ()

@end

@implementation TJPReconnectPolicy {
    //当前尝试次数
    NSInteger _currentAttempt;
    //网络任务的QoS级别
    dispatch_qos_class_t _qosClass;
}

- (instancetype)initWithMaxAttempst:(NSInteger)attempts baseDelay:(NSTimeInterval)delay qos:(TJPNetworkQoS)qos {
    if (self = [super init]) {
        _maxAttempts = attempts;
        _baseDelay = delay;
        _qosClass = [self qosClassFromEnum:qos];
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
    //如果超过最大重试次数 停止重试
    if (_currentAttempt >= _maxAttempts) {
        [self notifyReachMaxAttempts];
        return;
    }
    
    //指数退避+随机延迟的方式 避免服务器惊群效应
    NSTimeInterval delay = [self calculateDelay];

    //在指定的QoS级别的全局队列中调度重试任务
    dispatch_queue_t queue = dispatch_get_global_queue(_qosClass, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, ^{
        if ([TJPNetworkCoordinator shared].networkReachability) {
            if (connectionBlock) connectionBlock();
            self->_currentAttempt++;
        }
    });
    
}

- (NSTimeInterval)calculateDelay {
    return MIN(pow(_baseDelay, _currentAttempt) + arc4random_uniform(3), kMaxReconnectDelay);
}

- (void)notifyReachMaxAttempts {
    NSLog(@"Reached maximum retry attempts: %ld", (long)_maxAttempts);
}

- (void)reset {
    _currentAttempt = 0;
}



@end
