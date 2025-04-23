//
//  TJPHeartbeatProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPHeartbeatProtocol <NSObject>

- (void)startMonitoring;
- (void)stopMonitoring;
- (void)adjustInterval:(NSTimeInterval)interval;

@end

NS_ASSUME_NONNULL_END
