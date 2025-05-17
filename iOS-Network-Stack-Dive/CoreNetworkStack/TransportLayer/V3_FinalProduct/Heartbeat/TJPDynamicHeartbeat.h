//
//  TJPDynamicHeartbeat.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  动态心跳

#import <UIKit/UIKit.h>
#import "TJPCoreTypes.h"

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

//心跳队列
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *pendingHeartbeats;


//***********************************************
//前后台心跳优化

//心跳模式及策略
@property (nonatomic, assign) TJPHeartbeatMode heartbeatMode;
@property (nonatomic, assign) TJPHeartbeatStrategy heartbeatStrategy;
//当前app状态
@property (nonatomic, assign) TJPAppState currentAppState;

//配置参数
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *modeBaseIntervals;   //基础频率
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *modeMinIntervals;    //最小频率
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *modeMaxIntervals;    //最大频率

//状态跟踪
@property (nonatomic, assign) NSTimeInterval lastModeChangeTime;  //记录状态时间
@property (nonatomic, assign) BOOL isTransitioning;   //是否为状态过度
@property (nonatomic, assign) NSUInteger backgroundTransitionCounter;   //后台过渡次数


//后台任务支持
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;


/**
 * 配置指定心跳模式的参数
 *
 * @param baseInterval 基础心跳间隔（秒）
 * @param minInterval 最小心跳间隔（秒）
 * @param maxInterval 最大心跳间隔（秒）
 * @param mode 心跳模式
 */
- (void)configureWithBaseInterval:(NSTimeInterval)baseInterval  minInterval:(NSTimeInterval)minInterval maxInterval:(NSTimeInterval)maxInterval forMode:(TJPHeartbeatMode)mode;
/**
 * 手动设置心跳模式
 *
 * @param mode 心跳模式
 * @param force 是否强制设置（忽略当前应用状态）
 */
- (void)setHeartbeatMode:(TJPHeartbeatMode)mode force:(BOOL)force;



/// 获取心跳状态 用于Log日志或者调试问题
- (NSDictionary *)getHeartbeatStatus;

//***********************************************


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
