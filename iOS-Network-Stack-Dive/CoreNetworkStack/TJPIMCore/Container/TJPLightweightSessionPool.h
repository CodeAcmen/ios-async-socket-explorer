//
//  TJPLightweightSessionPool.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/16.
//  轻量级会话重用池

#import <Foundation/Foundation.h>
#import "TJPSessionProtocol.h"
#import "TJPNetworkDefine.h"

NS_ASSUME_NONNULL_BEGIN
@class TJPNetworkConfig, TJPConcreteSession;

//池配置结构体
typedef struct {
    NSUInteger maxPoolSize;         //每种类型最大池大小
    NSTimeInterval maxIdleTime;     //最大空闲时间
    NSTimeInterval cleanupInterval; //清理间隔
    NSUInteger maxReuseCount;       //最大复用次数
} TJPSessionPoolConfig;

// 会话池统计信息
typedef struct {
    NSUInteger totalSessions;       //总会话数
    NSUInteger activeSessions;      //活跃会话数
    NSUInteger pooledSessions;      //池中会话数
    NSUInteger hitCount;            //命中次数
    NSUInteger missCount;           //未命中次数
    double hitRate;                 //命中率
    
} TJPSessionPoolStats;

@interface TJPLightweightSessionPool : NSObject

// 池配置
@property (nonatomic, assign) TJPSessionPoolConfig config;

// 是否启用池功能
@property (nonatomic, assign) BOOL poolEnabled;

// 单例访问
+ (instancetype)sharedPool;


/**
 * 启动会话池
 * @param config 池配置
 */
- (void)startWithConfig:(TJPSessionPoolConfig)config;

/**
 * 停止会话池（清理所有会话）
 */
- (void)stop;

/**
 * 暂停池功能（临时禁用复用）
 */
- (void)pause;

/**
 * 恢复池功能
 */
- (void)resume;

/**
 * 获取会话（优先从池中复用）
 * @param type 会话类型
 * @param config 网络配置
 * @return 可用的会话实例
 */
- (id<TJPSessionProtocol>)acquireSessionForType:(TJPSessionType)type withConfig:(TJPNetworkConfig *)config;

/**
 * 归还会话到池中
 * @param session 要归还的会话
 */
- (void)releaseSession:(id<TJPSessionProtocol>)session;

/**
 * 强制移除会话（不放入池中）
 * @param session 要移除的会话
 */
- (void)removeSession:(id<TJPSessionProtocol>)session;


/**
 * 手动触发清理
 */
- (void)cleanup;

/**
 * 清理指定类型的会话
 * @param type 会话类型
 */
- (void)cleanupSessionsForType:(TJPSessionType)type;

/**
 * 预热池（提前创建会话）
 * @param type 会话类型
 * @param count 预创建数量
 * @param config 网络配置
 */
- (void)warmupPoolForType:(TJPSessionType)type
                    count:(NSUInteger)count
               withConfig:(TJPNetworkConfig *)config;

/**
 * 获取池统计信息
 */
- (TJPSessionPoolStats)getPoolStats;

/**
 * 获取指定类型的会话数量
 * @param type 会话类型
 */
- (NSUInteger)getSessionCountForType:(TJPSessionType)type;

/**
 * 获取池中会话数量
 * @param type 会话类型
 */
- (NSUInteger)getPooledSessionCountForType:(TJPSessionType)type;

/**
 * 重置统计信息
 */
- (void)resetStats;

/**
 * 打印池状态
 */
- (void)logPoolStatus;

/**
 * 获取详细的池信息
 */
- (NSDictionary *)getDetailedPoolInfo;


@end

NS_ASSUME_NONNULL_END
