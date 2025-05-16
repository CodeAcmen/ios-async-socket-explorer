//
//  TJPMetricsCollector.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/9.
//  指标收集器

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN
// 连接相关指标
extern NSString * const TJPMetricsKeyConnectionAttempts;
extern NSString * const TJPMetricsKeyConnectionSuccess;

// 心跳相关指标
extern NSString * const TJPMetricsKeyHeartbeatSend; //心跳消息发送书
extern NSString * const TJPMetricsKeyHeartbeatLoss;
extern NSString * const TJPMetricsKeyHeartbeatRTT;
extern NSString * const TJPMetricsKeyHeartbeatInterval;
extern NSString * const TJPMetricsKeyHeartbeatTimeoutInterval;

// 网络性能指标
extern NSString * const TJPMetricsKeyRTT;


// 流量统计指标
extern NSString * const TJPMetricsKeyBytesSend;
extern NSString * const TJPMetricsKeyBytesReceived;

// 数据包解析指标
extern NSString * const TJPMetricsKeyParsedPackets;
extern NSString * const TJPMetricsKeyParsedPacketsTime;
extern NSString * const TJPMetricsKeyParsedBufferSize;
extern NSString * const TJPMetricsKeyParseErrors;
extern NSString * const TJPMetricsKeyParsedErrorsTime;

// 负载统计指标
extern NSString * const TJPMetricsKeyPayloadBytes;
extern NSString * const TJPMetricsKeyParserResets;


// 消息统计指标
extern NSString * const TJPMetricsKeyMessageSend;       // 消息发送总数
extern NSString * const TJPMetricsKeyMessageAcked;      // 消息确认总数
extern NSString * const TJPMetricsKeyMessageTimeout;    // 消息超时总数

// 消息类型统计指标
extern NSString * const TJPMetricsKeyControlMessageSend;  // 控制消息发送数
extern NSString * const TJPMetricsKeyNormalMessageSend;   // 普通消息发送数
extern NSString * const TJPMetricsKeyMessageRetried;      // 消息重传总数


// 会话错误数和状态指标
extern NSString * const TJPMetricsKeyErrorCount;          // 错误总数
extern NSString * const TJPMetricsKeySessionReconnects;   // 会话重连次数
extern NSString * const TJPMetricsKeySessionDisconnects;  // 会话断开次数


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


/// 错误记录
- (void)recordError:(NSError *)error forKey:(NSString *)key;
/// 重连错误
- (NSArray<NSDictionary *> *)recentErrors;


@end

NS_ASSUME_NONNULL_END


