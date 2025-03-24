//
//  TJPDynamicHeartbeat.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TJPConcreteSession, TJPNetworkCondition, TJPSequenceManager;
@protocol TJPSessionProtocol;
@interface TJPDynamicHeartbeat : NSObject

@property (nonatomic, strong) TJPSequenceManager *sequenceManager;

@property (nonatomic, assign) NSTimeInterval baseInterval;
@property (nonatomic, assign) NSTimeInterval currentInterval;


/// 初始化方法
- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval;

/// 开始监听
- (void)startMonitoringForSession:(id<TJPSessionProtocol>)session;
/// 停止监听
- (void)stopMonitoring;
/// 调整心跳频率
- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition;
/// 心跳回应
- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence;
@end

NS_ASSUME_NONNULL_END
