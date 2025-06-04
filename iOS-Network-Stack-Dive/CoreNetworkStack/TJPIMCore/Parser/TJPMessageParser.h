//
//  TJPMessageParser.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  协议解析器

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
@class TJPParsedPacket, TJPMessageParser;

@protocol TJPMessageStrategyDelegate <NSObject>
@optional
/// 是否使用环形缓冲区   YES使用 NO不使用
- (BOOL)shouldUserRingBufferForParser:(TJPMessageParser *)parser;
/// 推荐缓冲区容量
- (NSUInteger)recommendedCapacityForParser:(TJPMessageParser *)parser;
/// 缓冲区切换通知
- (void)parser:(TJPMessageParser *)parser didSwitchToImplementation:(NSString *)impl reason:(NSString *)reason;
/// 缓冲区错误处理策略  YES继续使用当前实现 NO切换到备用实现
- (BOOL)parser:(TJPMessageParser *)parser shouldContinueAfterError:(NSError *)error;

@end


@interface TJPMessageParser : NSObject

@property (nonatomic, weak) id<TJPMessageStrategyDelegate> strategyDelegate;


/// 当前状态
@property (nonatomic, assign, readonly) TJPParseState currentState;
/// 缓冲区 用于数据监控
@property (nonatomic, readonly) NSMutableData *buffer;
/// 当前协议头
@property (nonatomic, readonly) TJPFinalAdavancedHeader currentHeader;
/// 当前策略
@property (nonatomic, readonly) TJPBufferStrategy currentStrategy;


/// 开关控制是否使用环形缓冲区
@property (nonatomic, readonly) BOOL isUseRingBuffer;
/// 缓冲区总容量
@property (nonatomic, readonly) NSUInteger bufferCapacity;
/// 已使用大小
@property (nonatomic, readonly) NSUInteger userdBufferSize;
/// 使用率 0.0 - 1.0
@property (nonatomic, readonly) CGFloat bufferUsageRatio;


///  缓冲区添加数据
- (void)feedData:(NSData *)data;
/// 是否是完整数据
- (BOOL)hasCompletePacket;
/// 获取下一个数据
- (TJPParsedPacket *)nextPacket;
/// 重置数据
- (void)reset;



- (instancetype)init;
/// 是否使用环形缓冲区初始化
- (instancetype)initWithRingBufferEnabled:(BOOL)enabled;
/// 使用缓冲区选择策略进行初始化
- (instancetype)initWithBufferStrategy:(TJPBufferStrategy)strategy;
/// 完整配置初始化
- (instancetype)initWithBufferStrategy:(TJPBufferStrategy)strategy capacity:(NSUInteger)capacity;

//************************************************
//新增控制切换 调试方法

/// 切换到环形缓冲区
- (BOOL)switchToRingBuffer;
/// 切换到环形缓冲区并指定容量
- (BOOL)switchToRingBufferWithCapacity:(NSUInteger)capacity;
/// 切换到传统缓冲区
- (void)switchToTraditionBuffer;
/// 切换到最优模式 根据条件自动选择
- (BOOL)switchToOptimalMode;

/// 打印当前缓冲区信息
- (void)printBufferStatus;
/// 获取缓冲区统计信息
- (NSDictionary *)bufferStatistics;




@end

NS_ASSUME_NONNULL_END
