//
//  TJPConnectStateMachine+TJPMetrics.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//  状态机增强埋点

#import "TJPConnectStateMachine.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPConnectStateMachine (TJPMetrics)

/// 增强版状态进入时间
@property (nonatomic, assign) NSTimeInterval metrics_stateEnterTime;



@end

NS_ASSUME_NONNULL_END
