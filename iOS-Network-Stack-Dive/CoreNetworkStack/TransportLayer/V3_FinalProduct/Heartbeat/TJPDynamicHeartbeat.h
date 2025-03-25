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

@property (nonatomic, strong) NSDate *lastHeartbeatTime;

@property (nonatomic, strong) TJPSequenceManager *sequenceManager;

@property (nonatomic, assign) NSTimeInterval baseInterval;
@property (nonatomic, assign) NSTimeInterval currentInterval;

//改为声明在属性是为了单元测试
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;



/// 初始化方法
- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval seqManager:(TJPSequenceManager *)seqManager;

/// 开始监听
- (void)startMonitoringForSession:(id<TJPSessionProtocol>)session;
/// 停止监听
- (void)stopMonitoring;
/// 调整心跳频率
- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition;
/// 发送心跳
- (void)sendHeartbeat;
/// 心跳回应
- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence;
@end

NS_ASSUME_NONNULL_END
