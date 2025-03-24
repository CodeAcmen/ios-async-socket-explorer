//
//  TJPSequenceManager.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPSequenceManager : NSObject
@property (nonatomic, assign, readonly) uint32_t currentSequence;


- (uint32_t)nextSequence;
- (void)resetSequence;

@end

NS_ASSUME_NONNULL_END
