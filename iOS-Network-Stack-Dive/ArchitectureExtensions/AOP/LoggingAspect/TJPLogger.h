//
//  TJPLogger.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TJPLogModel;
@interface TJPLogger : NSObject

/// 全局id用于链路追踪
@property (nonatomic, copy, readonly) NSString *traceId;

+ (instancetype)shared;

- (void)log:(TJPLogModel *)log;

@end

NS_ASSUME_NONNULL_END
