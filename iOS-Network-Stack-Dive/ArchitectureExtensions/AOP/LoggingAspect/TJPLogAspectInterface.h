//
//  TJPLogAspectInterface.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//  日志切面接口

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPLogAspectInterface <NSObject>
//日志触发点
typedef NS_ENUM(NSUInteger, TJPLogTriggerPoint) {
    TJPLogTriggerBeforeMethod,          //方法执行前
    TJPLogTriggerAfterMethod,           //方法执行后
    TJPLogTriggerOnException            //发生异常时
};

//日志配置  方法过滤
typedef struct TJPLogConfig {
    Class targetClass;          //目标类
    SEL targetSelector;         //目标方法
    Protocol *targetProtocol;   //目标协议
}TJPLogConfig;



@end

NS_ASSUME_NONNULL_END
