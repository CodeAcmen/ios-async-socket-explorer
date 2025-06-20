//
//  TJPLogManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/19.
//  日志管理器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TJPLogLevel) {
    TJPLogLevelDebug = 0,
    TJPLogLevelInfo,
    TJPLogLevelWarn,
    TJPLogLevelMock,
    TJPLogLevelError
};

@interface TJPLogManager : NSObject

/// 是否开启详细日志
@property (nonatomic, assign) BOOL debugLoggingEnabled;
/// 最低日志级别
@property (nonatomic, assign) TJPLogLevel minLogLevel;
/// Log日志限流间隔
@property (nonatomic, assign) NSTimeInterval logThrottleInterval;

/// 单例
+ (instancetype)sharedManager;

+ (TJPLogLevel)levelFromString:(NSString *)levelString;


- (BOOL)shouldLogWithLevel:(TJPLogLevel)level;
/// 过滤日志消息
- (void)throttledLog:(NSString *)message level:(NSUInteger)level tag:(NSString *)tag;




@end

NS_ASSUME_NONNULL_END
