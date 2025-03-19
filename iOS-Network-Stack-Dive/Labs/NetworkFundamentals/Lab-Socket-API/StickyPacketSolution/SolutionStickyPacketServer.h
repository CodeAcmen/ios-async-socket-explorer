//
//  SolutionStickyPacketServer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SolutionStickyPacketServer : NSObject

@property (nonatomic, copy) void(^serverReceiveChatComplete)(NSString *message);

- (void)startServerOnPort:(uint16_t)port;
- (void)stopServer;

@end

NS_ASSUME_NONNULL_END
