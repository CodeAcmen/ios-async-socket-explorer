//
//  TJPNetworkCondition.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//  加权滑动窗口式的网络质量采样器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TJPNetworkQualityLevel) {
    TJPNetworkQualityUnknown,       //未知状态
    TJPNetworkQualityExcellent,     //网络很好
    TJPNetworkQualityGood,          //网络良好
    TJPNetworkQualityFair,          //网络一般
    TJPNetworkQualityPoor           //网络很差
};

@interface TJPNetworkCondition : NSObject

/// 往返延迟 毫秒
@property (nonatomic, assign) NSTimeInterval roundTripTime;
/// 丢包率 百分比
@property (nonatomic, assign) CGFloat packetLossRate;
/// 宽带估算 Mbps
//@property (nonatomic, assign) CGFloat bandwidthEstimate;

/// 网络质量等级 (根据指标自动计算)
@property (nonatomic, assign, readonly) TJPNetworkQualityLevel qualityLevel;
/// 是否拥塞
@property (nonatomic, assign, readonly) BOOL isCongested;


- (void)updateRTTWithSample:(NSTimeInterval)rtt;
- (void)updateLostWithSample:(BOOL)isLost;

@end

NS_ASSUME_NONNULL_END


