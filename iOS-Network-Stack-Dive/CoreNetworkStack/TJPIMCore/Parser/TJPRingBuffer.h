//
//  TJPRingBuffer.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/26.
//  环形缓冲区

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPRingBuffer : NSObject

/// 缓冲区总容量大小  单位字节
@property (nonatomic, readonly) NSUInteger capacity;

/// 当前缓冲区已使用大小
@property (nonatomic, readonly) NSUInteger usedSize;

/// 当前缓冲区剩余可写入空间
@property (nonatomic, readonly) NSUInteger availableSpace;

/// 当前读取索引位置
@property (nonatomic, readonly) NSUInteger readIndex;

/// 当前写入索引位置
@property (nonatomic, readonly) NSUInteger writeIndex;


/// 初始化方法
/// - Parameter capacity: 缓冲区容量
- (instancetype)initWithCapacity:(NSUInteger)capacity;


/// 向缓冲区写入数据
/// - Parameter data: 要写入的数据
- (NSUInteger)writeData:(NSData *)data;


/// 向缓冲区写入原始字节数据
/// - Parameters:
///   - bytes: 字节数据指针
///   - length: 数据长度
- (NSUInteger)writeBytes:(const void *)bytes length:(NSUInteger)length;


/// 冲缓冲区读取指定长度的数据
/// - Parameter length: 要读取的字节数
- (NSData *)readData:(NSUInteger)length;


/// 从缓冲区读取数据到指定buffer
/// - Parameters:
///   - buffer: 目标缓冲区
///   - length: 要读取的字节数
- (NSUInteger)readBytes:(void *)buffer length:(NSUInteger)length;



/// 预览指定长度数据
/// - Parameter length: 预览字节数
- (NSData *)peekData:(NSUInteger)length;


/// 预览数据到指定buffer(不移动读指针)
/// - Parameters:
///   - buffer: 目标缓冲区
///   - length: 要预览的字节数
- (NSUInteger)peekBytes:(void *)buffer length:(NSUInteger)length;



/// 跳过指定长度数据 仅仅移动读指针
/// - Parameter length: 要跳过的长度
- (NSUInteger)skipBytes:(NSUInteger)length;


/// 检查是否有足够的数据可读
/// - Parameter length: 要检查的数据长度
- (BOOL)hasAvailableData:(NSUInteger)length;



/// 缓冲区使用率
- (CGFloat)usageRatio;

- (void)reset;


@end

NS_ASSUME_NONNULL_END
