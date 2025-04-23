//
//  TJPSessionPacketMonitor.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPSessionPacketMonitor : NSObject

/// 记录新数据包大小（线程安全）
- (void)recordPacketSize:(NSUInteger)size;

/// 获取最近N个包的平均大小（线程安全）
- (CGFloat)averageSizeForLastPackets:(NSUInteger)count;

/// 重置监控数据
- (void)reset;

@end

NS_ASSUME_NONNULL_END
