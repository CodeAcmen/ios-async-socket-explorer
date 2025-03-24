//
//  TJPReconnectPolicy.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPReconnectPolicy : NSObject

@property (nonatomic, assign) NSInteger maxAttempts;
@property (nonatomic, assign) NSTimeInterval baseDelay;


- (instancetype)initWithMaxAttempst:(NSInteger)attempts baseDelay:(NSTimeInterval)delay qos:(TJPNetworkQoS)qos;

- (void)attemptConnectionWithBlock:(dispatch_block_t)connectionBlock;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
