//
//  TJPSequenceManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPSequenceManager : NSObject
/// 当前序列号
@property (nonatomic, assign, readonly) uint32_t currentSequence;


/// 获取下个序列号
- (uint32_t)nextSequence;
/// 重置序列号
- (void)resetSequence;

@end

NS_ASSUME_NONNULL_END
