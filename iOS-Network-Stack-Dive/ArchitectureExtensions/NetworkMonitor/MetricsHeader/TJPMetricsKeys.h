//
//  TJPMetricsKeys.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/18.
//

#import <Foundation/Foundation.h>

#pragma mark - 基础指标键
extern NSString * const TJPMetricsKeyConnectionAttempts;
extern NSString * const TJPMetricsKeyConnectionSuccess;


#pragma mark - 网络相关指标
extern NSString * const TJPMetricsKeyRTT;                       // 通用RTT指标(s)

#pragma mark - 心跳指标相关
// 基本计数指标
extern NSString * const TJPMetricsKeyHeartbeatSend;             // 心跳发送次数
extern NSString * const TJPMetricsKeyHeartbeatLoss;             // 心跳丢失次数
extern NSString * const TJPMetricsKeyHeartbeatRTT;              // 心跳RTT值(ms)
extern NSString * const TJPMetricsKeyHeartbeatInterval;         // 心跳间隔(s)
extern NSString * const TJPMetricsKeyHeartbeatTimeoutInterval;  // 心跳超时间隔(s)

// 心跳事件类型键
extern NSString * const TJPHeartbeatEventSend;                  // 心跳发送事件
extern NSString * const TJPHeartbeatEventACK;                   // 心跳确认事件
extern NSString * const TJPHeartbeatEventTimeout;               // 心跳超时事件
extern NSString * const TJPHeartbeatEventFailed;                // 心跳发送失败事件
extern NSString * const TJPHeartbeatEventModeChanged;           // 心跳模式变更事件
extern NSString * const TJPHeartbeatEventIntervalChanged;       // 心跳间隔变更事件
extern NSString * const TJPHeartbeatEventStarted;               // 心跳监控启动事件
extern NSString * const TJPHeartbeatEventStopped;               // 心跳监控停止事件

// 心跳状态参数键   用于事件参数中的字段名
extern NSString * const TJPHeartbeatParamSequence;              // 序列号字段
extern NSString * const TJPHeartbeatParamRTT;                   // RTT字段
extern NSString * const TJPHeartbeatParamInterval;              // 当前间隔字段
extern NSString * const TJPHeartbeatParamMode;                  // 心跳模式字段
extern NSString * const TJPHeartbeatParamOldMode;               // 旧心跳模式字段
extern NSString * const TJPHeartbeatParamNewMode;               // 新心跳模式字段
extern NSString * const TJPHeartbeatParamNetworkQuality;        // 网络质量字段
extern NSString * const TJPHeartbeatParamState;                 // 状态字段
extern NSString * const TJPHeartbeatParamReason;                // 原因字段



// 心跳诊断键
extern NSString * const TJPHeartbeatDiagnosticSendCount;
extern NSString * const TJPHeartbeatDiagnosticLossCount;
extern NSString * const TJPHeartbeatDiagnosticLossRate;

// 时间指标键
extern NSString * const TJPHeartbeatDiagnosticAverageRTT;
extern NSString * const TJPHeartbeatDiagnosticCurrentInterval;

// 事件历史键
extern NSString * const TJPHeartbeatDiagnosticRecentTimeouts;
extern NSString * const TJPHeartbeatDiagnosticRecentModeChanges;
extern NSString * const TJPHeartbeatDiagnosticRecentSends;
extern NSString * const TJPHeartbeatDiagnosticRecentACKs;

