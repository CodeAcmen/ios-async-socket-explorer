//
//  TJPSequenceManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPSequenceManager.h"

@implementation TJPSequenceManager {
    uint32_t _sequence;
    dispatch_queue_t _serialQueue;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = dispatch_queue_create("com.tjp.sequenceManager.seqSerialQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (uint32_t)nextSequence {
    __block uint32_t nextSeq = 0;
    dispatch_async(self->_serialQueue, ^{
        self->_sequence = (self->_sequence + 1) % UINT32_MAX;
        nextSeq = self->_sequence;
    });
    return nextSeq;    
}

- (void)resetSequence {
    dispatch_async(self->_serialQueue, ^{
        self->_sequence = 0;
    });
}

- (uint32_t)currentSequence {
    return _sequence;
}

@end
