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

//网络质量采集器
@property (nonatomic, strong) TJPNetworkCondition *networkCondition;
//序列号管理器
@property (nonatomic, strong) TJPSequenceManager *sequenceManager;

//基础心跳时间
@property (nonatomic, assign) NSTimeInterval baseInterval;
//当前心跳时间
@property (nonatomic, assign) NSTimeInterval currentInterval;

//改为声明在属性是为了单元测试
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;



/// 初始化方法
- (instancetype)initWithBaseInterval:(NSTimeInterval)baseInterval seqManager:(TJPSequenceManager *)seqManager session:(id<TJPSessionProtocol>)session;

/// 开始监听
- (void)startMonitoring;
/// 停止监听
- (void)stopMonitoring;
/// 更新session
- (void)updateSession:(id<TJPSessionProtocol>)session;
/// 调整心跳频率
- (void)adjustIntervalWithNetworkCondition:(TJPNetworkCondition *)condition;
/// 发送心跳
- (void)sendHeartbeat;
/// 发送心跳失败
- (void)sendHeartbeatFailed;
/// 心跳回应
- (void)heartbeatACKNowledgedForSequence:(uint32_t)sequence;
/// 心跳超时
- (void)handleHeaderbeatTimeoutForSequence:(uint32_t)sequence;
/// 是否属于心跳
- (BOOL)isHeartbeatSequence:(uint32_t)sequence;

@end

NS_ASSUME_NONNULL_END
