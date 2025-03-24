//
//  TJPNetworkCondition.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPNetworkCondition.h"

@implementation TJPNetworkCondition

+ (instancetype)conditionWithMetrics:(NSURLSessionTaskMetrics *)metriscs {
    TJPNetworkCondition *condition = [TJPNetworkCondition new];
    
    //计算RTT
    __block NSTimeInterval totalRTT = 0;
    [metriscs.transactionMetrics enumerateObjectsUsingBlock:^(NSURLSessionTaskTransactionMetrics * _Nonnull tm, NSUInteger idx, BOOL * _Nonnull stop) {
        totalRTT += [tm.connectEndDate timeIntervalSinceDate:tm.connectStartDate] * 1000;
    }];
    condition.roundTripTime = totalRTT / metriscs.transactionMetrics.count;
    
    //计算丢包率
    condition.packetLossRate = [condition calculatePacketLoss];
    
    return condition;
}

- (CGFloat)calculatePacketLoss {
//    return arc4random_uniform(2000) / 100.0;
    
    if (self.sentPackets == 0) {
        return 0;
    }
    
    //丢包率=丢失的包数/总发送的包数×100
    CGFloat packetLossRate = ((self.sentPackets - self.receivedPackets) / (CGFloat)self.sentPackets) * 100;
    return packetLossRate;
}


- (TJPNetworkQualityLevel)qualityLevel {
    if (_roundTripTime < 100 && _packetLossRate < 2) {
        return TJPNetworkQualityExcellent;
    }else if (_roundTripTime < 300 && _packetLossRate < 5) {
        return TJPNetworkQualityGood;
    }else if (_roundTripTime < 500 && _packetLossRate < 10) {
        return TJPNetworkQualityFair;
    }
    return TJPNetworkQualityPoor;
}

- (BOOL)isCongested {
    return (_packetLossRate > 15 || _roundTripTime > 800);
}






@end
