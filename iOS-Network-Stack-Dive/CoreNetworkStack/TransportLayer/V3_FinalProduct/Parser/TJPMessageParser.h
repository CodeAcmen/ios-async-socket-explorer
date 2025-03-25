//
//  TJPMessageParser.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  协议解析器

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPParsedPacket;
@interface TJPMessageParser : NSObject
@property (nonatomic, assign, readonly) TJPParseState currentState;

//单元测试用
@property (nonatomic, strong, readonly) NSMutableData *buffer;
@property (nonatomic, readonly) TJPFinalAdavancedHeader currentHeader;



- (void)feedData:(NSData *)data;

- (BOOL)hasCompletePacket;

- (TJPParsedPacket *)nextPacket;

- (void)reset;

- (void)parseHeader;

@end

NS_ASSUME_NONNULL_END
