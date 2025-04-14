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



#define TJPSCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define TJPSCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)



#endif /* TJPNetworkDefine_h */
