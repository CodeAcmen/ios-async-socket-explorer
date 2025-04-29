//
//  TJPSequenceManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPSequenceManager : NSObject
/// 重置前回调
@property (nonatomic, copy) void (^sequenceResetHandler)(TJPMessageCategory category);


/// 根据类型获取下个序列号
- (uint32_t)nextSequenceForCategory:(TJPMessageCategory)category;
/// 检查是否为该类别的序列号
- (BOOL)isSequenceForCategory:(uint32_t)sequence category:(TJPMessageCategory)category;
/// 重置序列号
- (void)resetSequence;
/// 重置当前类别序列号
- (void)resetSequence:(TJPMessageCategory)category;
/// 获取类别的当前序列号
- (uint32_t)currentSequenceForCategory:(TJPMessageCategory)category;

@end

NS_ASSUME_NONNULL_END
