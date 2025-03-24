//
//  TJPNetworkCondition.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//  处理网络状况的各项指标

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TJPNetworkQualityLevel) {
    TJPNetworkQualityExcellent      = 1 << 0,
    TJPNetworkQualityGood           = 1 << 1,
    TJPNetworkQualityFair           = 1 << 2,
    TJPNetworkQualityPoor           = 1 << 3

};

@interface TJPNetworkCondition : NSObject
/// 发送的数据包数
@property (nonatomic, assign) NSInteger sentPackets;
/// 接收到的数据包数
@property (nonatomic, assign) NSInteger receivedPackets;

/// 往返延迟 毫秒
@property (nonatomic, assign) NSTimeInterval roundTripTime;
/// 丢包率 百分比
@property (nonatomic, assign) CGFloat packetLossRate;
/// 宽带估算 Mbps
@property (nonatomic, assign) CGFloat bandwidthEstimate;

@property (nonatomic, assign, readonly) TJPNetworkQualityLevel qualityLevel;
/// 是否拥塞
@property (nonatomic, assign, readonly) BOOL isCongested;


@end

NS_ASSUME_NONNULL_END
