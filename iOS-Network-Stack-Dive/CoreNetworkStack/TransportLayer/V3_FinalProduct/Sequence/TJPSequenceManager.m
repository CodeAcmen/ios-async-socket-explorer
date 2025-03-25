//
//  TJPSequenceManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPSequenceManager.h"
#import <os/lock.h>

@implementation TJPSequenceManager {
    uint32_t _sequence;
    os_unfair_lock _lock;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _sequence = 0;
    }
    return self;
}


- (uint32_t)nextSequence {
    os_unfair_lock_lock(&_lock);
    _sequence = (_sequence % UINT32_MAX ) + 1;
    uint32_t nextSeq = _sequence;
    os_unfair_lock_unlock(&_lock);
    return nextSeq;
}

- (void)resetSequence {
    os_unfair_lock_lock(&_lock);
    _sequence = 0;
    os_unfair_lock_unlock(&_lock);
}

- (uint32_t)currentSequence {
    os_unfair_lock_lock(&_lock);
    uint32_t seq = _sequence;
    os_unfair_lock_unlock(&_lock);
    return seq;
}

@end
