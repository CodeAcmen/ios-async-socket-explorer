//
//  JZNetworkDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//  通用定义类

#ifndef JZIMDefine_h
#define JZIMDefine_h

//安全断言
#define AssertMainThread() NSAssert([NSThread isMainThread], @"必须在主线程执行")


#define TJPLOG_INFO(fmt, ...) NSLog(@"[INFO] " fmt, ##__VA_ARGS__)
#define TJPLOG_WARN(fmt, ...) NSLog(@"[WARN] " fmt, ##__VA_ARGS__)
#define TJPLOG_ERROR(fmt, ...) NSLog(@"[ERROR] " fmt, ##__VA_ARGS__)
#define TJPLOG_MOCK(fmt, ...) NSLog(@"[MOCK] " fmt, ##__VA_ARGS__)



#define kNetworkFatalErrorNotification @"kNetworkFatalErrorNotification"
#define kSessionDataReceiveNotification @"kSessionDataReceiveNotification"




#endif /* JZNetworkDefine_h */
