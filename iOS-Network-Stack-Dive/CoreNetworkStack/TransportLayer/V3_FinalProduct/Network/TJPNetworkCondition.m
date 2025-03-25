//
//  TJPNetworkCondition.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPNetworkCondition.h"


#define kMaxRTTSamples 10   //RTT样本数量
#define kWeightFactor 0.1  //丢包率加权因子

@interface TJPNetworkCondition ()

/// 记录数据
@property (nonatomic, strong) NSMutableArray<NSNumber *> *rttSamples;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *lostSamples;


@end


@implementation TJPNetworkCondition

- (instancetype)init {
    if (self = [super init]) {
        //默认数据 RTT0ms 丢包率0.0
        _roundTripTime = 0;
        _packetLossRate = 0.0;
        _rttSamples = [[NSMutableArray alloc] initWithCapacity:kMaxRTTSamples];
        _lostSamples = [[NSMutableArray alloc] initWithCapacity:kMaxRTTSamples];
    }
    return self;
}

- (void)updateRTTWithSample:(NSTimeInterval)rtt {
    @synchronized (self) {
        if (_rttSamples.count >= kMaxRTTSamples) {
            [_rttSamples removeObjectAtIndex:0];
        }
        [_rttSamples addObject:@(rtt)];
        
        //更新当前RTT
        _roundTripTime = [self _weightAverageForSamples:_rttSamples];
    }
}
- (void)updateLostWithSample:(BOOL)isLost {
    @synchronized (self) {
        if (_lostSamples.count >= kMaxRTTSamples) {
            [_lostSamples removeObjectAtIndex:0];
        }
        [_lostSamples addObject:@(isLost ? 1.0 : 0.0)];
        
        //计算丢包率
        CGFloat totalLost = 0.0;
        for (NSNumber *lost in _lostSamples) {
            totalLost += lost.floatValue;
        }
        _packetLossRate = (totalLost / _lostSamples.count) * 100;
    }
}

- (CGFloat)_weightAverageForSamples:(NSMutableArray<NSNumber *> *)samples {
    //总和
    CGFloat sum = 0;
    //权重
    CGFloat weightSum = 0;
    for (int i = 0; i < samples.count; i++) {
        //越新的样本权重越高
        CGFloat weight = 1.0 + (i * 0.2);
        sum += samples[i].floatValue * weight;
        weightSum += weight;
    }
    return sum / weightSum;
}



- (TJPNetworkQualityLevel)qualityLevel {    
    if (_roundTripTime < 100 && _packetLossRate < 2) {
        return TJPNetworkQualityExcellent;
    } else if (_roundTripTime < 300 && _packetLossRate < 5) {
        return TJPNetworkQualityGood;
    } else if (_roundTripTime < 500 && _packetLossRate < 10) {
        return TJPNetworkQualityFair;
    } else if (_roundTripTime < 800 && _packetLossRate < 15) {
        return TJPNetworkQualityPoor;
    }else {
        return TJPNetworkQualityUnknown;
    }
}

- (BOOL)isCongested {
    return (_packetLossRate > 10 || _roundTripTime > 500);
}


@end


