//
//  TJPMetricsCollector.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//  指标收集器

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const TJPMetricsKeyConnectionAttempts;
extern NSString * const TJPMetricsKeyConnectionSuccess;
extern NSString * const TJPMetricsKeyHeartbeatSend;
extern NSString * const TJPMetricsKeyHeartbeatLoss;
extern NSString * const TJPMetricsKeyHeartbeatRTT;

extern NSString * const TJPMetricsKeyRTT;
extern NSString * const TJPMetricsKeyHeartbeatInterval;
extern NSString * const TJPMetricsKeyHeartbeatTimeoutInterval;


extern NSString * const TJPMetricsKeyBytesSend;
extern NSString * const TJPMetricsKeyBytesReceived;


extern NSString * const TJPMetricsKeyParsedPackets;
extern NSString * const TJPMetricsKeyParsedPacketsTime;
extern NSString * const TJPMetricsKeyParsedBufferSize;
extern NSString * const TJPMetricsKeyParseErrors;
extern NSString * const TJPMetricsKeyParsedErrorsTime;
extern NSString * const TJPMetricsKeyPayloadBytes;
extern NSString * const TJPMetricsKeyParserResets;



@interface TJPMetricsCollector : NSObject

//流量统计
@property (nonatomic, readonly) NSUInteger byteSend;
@property (nonatomic, readonly) NSUInteger byteReceived;



+ (instancetype)sharedInstance;


/// 计数器操作
- (void)incrementCounter:(NSString *)key;
/// 带增量的计数器
- (void)incrementCounter:(NSString *)key by:(NSUInteger)value;
/// 获取计数器
- (NSUInteger)counterValue:(NSString *)key;

- (void)addValue:(NSUInteger)value forKey:(NSString *)key;

/// 时间样本记录 (秒级单位)
- (void)addTimeSample:(NSTimeInterval)duration forKey:(NSString *)key;
- (NSTimeInterval)averageDuration:(NSString *)key;

/// 连接成功率
- (float)connectSuccessRate;
/// 平均往返时间
- (NSTimeInterval)averageRTT;
/// 丢包率
- (float)packetLossRate;

/// 指定状态平均处理时间
- (NSTimeInterval)averageStateDuration:(TJPConnectState)state;
/// 指定事件平均处理时间
- (NSTimeInterval)averageEventDuration:(TJPConnectEvent)event;




@end

NS_ASSUME_NONNULL_END


