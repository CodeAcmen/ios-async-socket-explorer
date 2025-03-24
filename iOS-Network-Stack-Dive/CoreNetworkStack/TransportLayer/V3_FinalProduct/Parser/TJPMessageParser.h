//
//  TJPMessageParser.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPParsedPacket;
@interface TJPMessageParser : NSObject
@property (nonatomic, assign, readonly) TJPParseState currentState;


- (void)feedData:(NSData *)data;

- (BOOL)hasCompletePacket;

- (TJPParsedPacket *)nextPacket;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
