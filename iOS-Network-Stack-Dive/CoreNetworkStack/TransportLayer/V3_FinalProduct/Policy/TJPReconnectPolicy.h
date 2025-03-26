//
//  TJPReconnectPolicy.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  重试策略

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPReconnectPolicy : NSObject
/// 最大尝试数
@property (nonatomic, assign) NSInteger maxAttempts;
/// 基础延迟
@property (nonatomic, assign) NSTimeInterval baseDelay;

//单元测试用
@property (nonatomic, readonly) dispatch_qos_class_t qosClass;

@property (nonatomic, assign) NSInteger currentAttempt;


/// 初始化方法
- (instancetype)initWithMaxAttempst:(NSInteger)attempts baseDelay:(NSTimeInterval)delay qos:(TJPNetworkQoS)qos;
/// 尝试连接
- (void)attemptConnectionWithBlock:(dispatch_block_t)connectionBlock;
/// 计算延迟
- (NSTimeInterval)calculateDelay;
/// 最大重试次数
- (void)notifyReachMaxAttempts;
/// 重置
- (void)reset;

@end

NS_ASSUME_NONNULL_END
