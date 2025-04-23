//
//  TJPSessionPacketMonitor.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/21.
//

#import "TJPSessionPacketMonitor.h"

@interface TJPSessionPacketMonitor () {
    dispatch_queue_t _monitorQueue;
    NSMutableArray<NSNumber *> *_packetSizes;
}

@end

@implementation TJPSessionPacketMonitor

- (instancetype)init {
    if (self = [super init]) {
        _monitorQueue = dispatch_queue_create("com.session.monitor", DISPATCH_QUEUE_SERIAL);
        _packetSizes = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (void)recordPacketSize:(NSUInteger)size {
    dispatch_async(_monitorQueue, ^{
        // 保留最近10个包
        if (self->_packetSizes.count >= 10) {
            [self->_packetSizes removeObjectAtIndex:0];
        }
        [self->_packetSizes addObject:@(size)];
    });
}

- (CGFloat)averageSizeForLastPackets:(NSUInteger)count {
    __block CGFloat avg = 0;
    dispatch_sync(_monitorQueue, ^{
        NSUInteger actualCount = MIN(count, _packetSizes.count);
        if (actualCount == 0) {
            avg = 0;
            return;
        }
        
        NSUInteger total = 0;
        NSArray *targetPackets = [_packetSizes subarrayWithRange:
            NSMakeRange(_packetSizes.count - actualCount, actualCount)];
        
        for (NSNumber *num in targetPackets) {
            total += num.unsignedIntegerValue;
        }
        avg = (CGFloat)total / actualCount;
    });
    return avg;
}

- (void)reset {
    dispatch_async(_monitorQueue, ^{
        [self->_packetSizes removeAllObjects];
    });
}

@end
