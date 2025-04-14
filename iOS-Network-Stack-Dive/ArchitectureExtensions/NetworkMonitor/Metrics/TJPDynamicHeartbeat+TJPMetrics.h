//
//  TJPDynamicHeartbeat+TJPMetrics.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/11.
//

#import "TJPDynamicHeartbeat.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPDynamicHeartbeat (TJPMetrics)

// 心跳质量指标
@property (nonatomic, readonly) float heartbeatLossRate;      // 实时丢包率
@property (nonatomic, readonly) NSTimeInterval avgRTT;       // 动态平均往返时延
@property (nonatomic, readonly) NSTimeInterval currentInterval; // 当前心跳间隔

@end

NS_ASSUME_NONNULL_END


