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

@property (nonatomic, readonly) NSMutableData *buffer;


/// 开关控制是否使用环形缓冲区
@property (nonatomic, assign) BOOL useRingBuffer;


///  缓冲区添加数据
- (void)feedData:(NSData *)data;

/// 是否是完整数据
- (BOOL)hasCompletePacket;

/// 获取下一个数据
- (TJPParsedPacket *)nextPacket;

/// 重置数据
- (void)reset;


- (instancetype)initWithRingBufferEnabled:(BOOL)enabled;


@end

NS_ASSUME_NONNULL_END
