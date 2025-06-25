//
//  TJPNetworkDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/30.
//

#import "TJPLogManager.h"

#ifndef TJPNetworkDefine_h
#define TJPNetworkDefine_h

//网络监控开关
#if ENABLE_NETWORK_MONITORING
#define MONITOR_ENABLED 1
#else
#define MONITOR_ENABLED 0
#endif


//安全断言
#define AssertMainThread() NSAssert([NSThread isMainThread], @"必须在主线程执行")

#define TJPLOG(levelString, fmt, ...) \
    do { \
        TJPLogLevel __logLevel = [TJPLogManager levelFromString:(levelString)]; \
        if ([[TJPLogManager sharedManager] shouldLogWithLevel:__logLevel]) { \
            NSString *__msg = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
            [[TJPLogManager sharedManager] throttledLog:__msg \
                                                  level:__logLevel \
                                                    tag:@(__FUNCTION__)]; \
        } \
    } while (0)

#define TJPLOG_DEBUG(fmt, ...) TJPLOG(@"DEBUG", fmt, ##__VA_ARGS__)
#define TJPLOG_INFO(fmt, ...)  TJPLOG(@"INFO", fmt, ##__VA_ARGS__)
#define TJPLOG_WARN(fmt, ...)  TJPLOG(@"WARN", fmt, ##__VA_ARGS__)
#define TJPLOG_ERROR(fmt, ...) TJPLOG(@"ERROR", fmt, ##__VA_ARGS__)
#define TJPLOG_MOCK(fmt, ...)  TJPLOG(@"MOCK", fmt, ##__VA_ARGS__)
#define TJPLogDealloc()        TJPLOG(@"INFO", @"|DEALLOC| %s", __PRETTY_FUNCTION__)



#define kNetworkFatalErrorNotification @"kNetworkFatalErrorNotification"
#define kSessionDataReceiveNotification @"kSessionDataReceiveNotification"
#define kNetworkStatusChangedNotification @"kNetworkStatusChangedNotification"
#define kHeartbeatTimeoutNotification @"kHeartbeatTimeoutNotification"
#define kHeartbeatModeChangedNotification @"kHeartbeatModeChangedNotification"
#define kSessionNeedsReacquisitionNotification @"kSessionNeedsReacquisitionNotification"

// 消息相关通知
#define kTJPMessageSentNotification @"kTJPMessageSentNotification"
#define kTJPMessageFailedNotification @"kTJPMessageFailedNotification"
#define kTJPMessageReceivedNotification @"kTJPMessageReceivedNotification"






#define TJPMAX_BODY_SIZE (10 * 1024 * 1024)  // 10MB 最大消息体大小
#define TJPMAX_BUFFER_SIZE (20 * 1024 * 1024) // 20MB 最大缓冲区大小
#define TJPMAX_TIME_WINDOW 60 // 60秒时间窗口，防重放攻击

#define TJP_DEFAULT_RING_BUFFER_CAPACITY (128 * 1024) // 缓冲区大小 初始128kb




#define TJPSCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define TJPSCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)


static const uint32_t TJPSEQUENCE_CATEGORY_BITS = 8;              // 类别占用位数
static const uint32_t TJPSEQUENCE_BODY_BITS = 24;                 // 序列号占用位数
static const uint32_t TJPSEQUENCE_BODY_MASK = 0x00FFFFFF;         // 24位掩码
static const uint32_t TJPSEQUENCE_CATEGORY_MASK = 0xFF;           // 8位掩码
static const uint32_t TJPSEQUENCE_MAX_VALUE = 0x00FFFFFF;         // 最大序列号
static const uint32_t TJPSEQUENCE_WARNING_THRESHOLD = 0x00F00000; // 警告阈值(15M)
static const uint32_t TJPSEQUENCE_RESET_THRESHOLD = 0x00FF0000;   // 重置阈值(16M-1M)




//***************************************
// 心跳相关定义

// 前台心跳参数（秒）
static const NSTimeInterval kTJPHeartbeatForegroundBase = 30.0;  // 基础间隔
static const NSTimeInterval kTJPHeartbeatForegroundMin = 15.0;   // 最小间隔
static const NSTimeInterval kTJPHeartbeatForegroundMax = 300.0;  // 最大间隔

// 后台心跳参数（秒）
static const NSTimeInterval kTJPHeartbeatBackgroundBase = 90.0;  // 基础间隔
static const NSTimeInterval kTJPHeartbeatBackgroundMin = 45.0;   // 最小间隔
static const NSTimeInterval kTJPHeartbeatBackgroundMax = 600.0;  // 最大间隔

// 低电量模式心跳参数（秒）
static const NSTimeInterval kTJPHeartbeatLowPowerBase = 120.0;   // 基础间隔
static const NSTimeInterval kTJPHeartbeatLowPowerMin = 60.0;     // 最小间隔
static const NSTimeInterval kTJPHeartbeatLowPowerMax = 900.0;    // 最大间隔

// 调整因子
static const CGFloat kTJPHeartbeatNetworkPoorFactor = 2.5;       // 恶劣网络调整因子
static const CGFloat kTJPHeartbeatNetworkFairFactor = 1.5;       // 一般网络调整因子
static const CGFloat kTJPHeartbeatRTTRefValue = 200.0;           // RTT参考值(ms)
static const CGFloat kTJPHeartbeatRandomFactorMin = 0.9;         // 随机因子最小值
static const CGFloat kTJPHeartbeatRandomFactorMax = 1.1;         // 随机因子最大值

// 重试相关
static const NSUInteger kTJPHeartbeatMaxRetryCount = 3;          // 最大重试次数
static const NSTimeInterval kTJPHeartbeatMinTimeout = 15.0;      // 最小超时时间(秒)

//***************************************


#endif /* TJPNetworkDefine_h */
