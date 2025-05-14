//
//  TJPNetworkDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/30.
//

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

#if DEBUG
#define TJPLOG(level, fmt, ...) NSLog(@"[%@] [%@:%d %s] " fmt, level, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, __FUNCTION__, ##__VA_ARGS__)

#define TJPLOG_INFO(fmt, ...) TJPLOG(@"INFO", fmt, ##__VA_ARGS__)
#define TJPLOG_WARN(fmt, ...) TJPLOG(@"WARN", fmt, ##__VA_ARGS__)
#define TJPLOG_ERROR(fmt, ...) TJPLOG(@"ERROR", fmt, ##__VA_ARGS__)
#define TJPLOG_MOCK(fmt, ...) TJPLOG(@"MOCK", fmt, ##__VA_ARGS__)
#define TJPLogDealloc() NSLog(@"|DEALLOC| [%@:%d] %s", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, __FUNCTION__)

#else

#define TJPLOG(level, fmt, ...)
#define TJPLOG_INFO(fmt, ...)
#define TJPLOG_WARN(fmt, ...)
#define TJPLOG_ERROR(fmt, ...)
#define TJPLOG_MOCK(fmt, ...)
#define TJPLogDealloc()

#endif


#define kNetworkFatalErrorNotification @"kNetworkFatalErrorNotification"
#define kSessionDataReceiveNotification @"kSessionDataReceiveNotification"
#define kNetworkStatusChangedNotification @"kNetworkStatusChangedNotification"
#define kHeartbeatTimeoutNotification @"kHeartbeatTimeoutNotification"


#define TJPMAX_BODY_SIZE (10 * 1024 * 1024)  // 10MB 最大消息体大小
#define TJPMAX_BUFFER_SIZE (20 * 1024 * 1024) // 20MB 最大缓冲区大小
#define TJPMAX_TIME_WINDOW 60 // 60秒时间窗口，防重放攻击



#define TJPSCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define TJPSCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)


#define TJPSEQUENCE_BODY_MASK 0x00FFFFFF
#define TJPSEQUENCE_CATEGORY_MASK 0xFF
#define TJPSEQUENCE_WARNING_THRESHOLD 0xFFFFF0  // 接近最大值的警告阈值
#define TJPSEQUENCE_MAX_MASK 0xFFFFFF



#endif /* TJPNetworkDefine_h */
