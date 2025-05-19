//
//  TJPMetricsKeys.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/18.
//

#import "TJPMetricsKeys.h"


#pragma mark - 基础指标键
NSString * const TJPMetricsKeyConnectionAttempts = @"connection_attempts";
NSString * const TJPMetricsKeyConnectionSuccess = @"connection_success";

#pragma mark - 网络相关指标
NSString * const TJPMetricsKeyRTT = @"rtt";


#pragma mark - 心跳相关指标
NSString * const TJPMetricsKeyHeartbeatSend = @"heartbeat_send";
NSString * const TJPMetricsKeyHeartbeatLoss = @"heartbeat_loss";
NSString * const TJPMetricsKeyHeartbeatRTT = @"heartbeat_rtt";
NSString * const TJPMetricsKeyHeartbeatInterval = @"heartbeat_interval";
NSString * const TJPMetricsKeyHeartbeatTimeoutInterval = @"heartbeat_timeout_interval";


// 心跳事件类型
NSString * const TJPHeartbeatEventSend = @"heartbeat_event_send";
NSString * const TJPHeartbeatEventACK = @"heartbeat_event_ack";
NSString * const TJPHeartbeatEventTimeout = @"heartbeat_event_timeout";
NSString * const TJPHeartbeatEventFailed = @"heartbeat_event_failed";
NSString * const TJPHeartbeatEventModeChanged = @"heartbeat_event_mode_changed";
NSString * const TJPHeartbeatEventIntervalChanged = @"heartbeat_eventinterval_changed";
NSString * const TJPHeartbeatEventStarted = @"heartbeat_event_started";
NSString * const TJPHeartbeatEventStopped = @"heartbeat_event_stopped";

// 心跳状态类型
NSString * const TJPHeartbeatParamSequence = @"heartbeat_param_sequence";
NSString * const TJPHeartbeatParamRTT = @"heartbeat_param_rtt";
NSString * const TJPHeartbeatParamInterval = @"heartbeat_param_interval";
NSString * const TJPHeartbeatParamMode = @"heartbeat_param_mode";
NSString * const TJPHeartbeatParamOldMode = @"heartbeat_param_old_mode";
NSString * const TJPHeartbeatParamNewMode = @"heartbeat_param_new_mode";
NSString * const TJPHeartbeatParamNetworkQuality = @"heartbeat_param_network_quality";
NSString * const TJPHeartbeatParamState = @"heartbeat_param_state";
NSString * const TJPHeartbeatParamReason = @"heartbeat_param_reason";


#pragma mark - 心跳诊断键
// 基本计数指标键
NSString * const TJPHeartbeatDiagnosticSendCount = @"heartbeat_send_count";
NSString * const TJPHeartbeatDiagnosticLossCount = @"heartbeat_loss_count";
NSString * const TJPHeartbeatDiagnosticLossRate = @"heartbeat_loss_rate";

// 时间指标键
NSString * const TJPHeartbeatDiagnosticAverageRTT = @"average_rtt";
NSString * const TJPHeartbeatDiagnosticCurrentInterval = @"current_interval";

// 事件历史键
NSString * const TJPHeartbeatDiagnosticRecentTimeouts = @"recent_timeouts";
NSString * const TJPHeartbeatDiagnosticRecentModeChanges = @"recent_mode_changes";
NSString * const TJPHeartbeatDiagnosticRecentSends = @"recent_sends";
NSString * const TJPHeartbeatDiagnosticRecentACKs = @"recent_acks";
