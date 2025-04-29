//
//  TJPReconnectPolicy.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  重试策略

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
@class TJPReconnectPolicy;
@protocol TJPReconnectPolicyDelegate <NSObject>
@optional
- (void)reconnectPolicyDidReachMaxAttempts:(TJPReconnectPolicy *)reconnectPolicy;
- (NSString *)getCurrentConnectionState;
@end

@interface TJPReconnectPolicy : NSObject

@property (nonatomic, weak) id<TJPReconnectPolicyDelegate> delegate;


/// 最大尝试数
@property (nonatomic, assign) NSInteger maxAttempts;
/// 当前尝试次数
@property (nonatomic, assign) NSInteger currentAttempt;
/// 基础延迟
@property (nonatomic, assign) NSTimeInterval baseDelay;
/// 最大延迟
@property (nonatomic, assign) NSTimeInterval maxDelay;


//单元测试用
@property (nonatomic, readonly) dispatch_qos_class_t qosClass;



/// 初始化方法
- (instancetype)initWithMaxAttempst:(NSInteger)attempts baseDelay:(NSTimeInterval)delay qos:(TJPNetworkQoS)qos delegate:(id<TJPReconnectPolicyDelegate>)delegate;
/// 尝试连接
- (void)attemptConnectionWithBlock:(dispatch_block_t)connectionBlock;
/// 计算延迟
- (NSTimeInterval)calculateDelay;
/// 最大重试次数
- (void)notifyReachMaxAttempts;
/// 停止重试
- (void)stopRetrying;
/// 重置
- (void)reset;

@end

NS_ASSUME_NONNULL_END
