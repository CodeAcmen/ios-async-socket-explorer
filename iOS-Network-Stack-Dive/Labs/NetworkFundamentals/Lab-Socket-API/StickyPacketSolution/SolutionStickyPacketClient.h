//
//  SolutionStickyPacketClient.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SolutionStickyPacketClient : NSObject

- (void)connectToHost:(NSString *)host port:(uint16_t)port;
- (void)sendMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
