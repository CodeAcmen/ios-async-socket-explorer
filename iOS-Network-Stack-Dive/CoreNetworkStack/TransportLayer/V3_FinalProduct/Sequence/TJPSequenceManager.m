//
//  TJPSequenceManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPSequenceManager.h"
#import <os/lock.h>
#import "TJPNetworkDefine.h"

@implementation TJPSequenceManager {
    //根据类型对序列号分区
    uint32_t _sequences[4];
    os_unfair_lock _lock;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        memset(_sequences, 0, sizeof(_sequences));
    }
    return self;
}

- (uint32_t)nextSequenceForCategory:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);

    //获取目标类别的当前序列号
    uint32_t *categorySequence = &_sequences[category];
    
    //计算新序列号:类别8位 + 24位序列号
    *categorySequence = (*categorySequence + 1) & TJPSEQUENCE_BODY_MASK;
    
    
    //增加最大值判断
    if (*categorySequence > TJPSEQUENCE_WARNING_THRESHOLD) {
        //接近最大值时警告
        if (self.sequenceResetHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sequenceResetHandler(category);
            });
        }
    }
    
    //如果达到最大值 重置
    if (*categorySequence >= TJPSEQUENCE_MAX_MASK) {
        *categorySequence = 0;
    }
    
    
    //通过与上掩码取出24位序列号
    uint32_t nextSeq = ((uint32_t)category << 24) | *categorySequence;
    
    os_unfair_lock_unlock(&_lock);
    
    return nextSeq;
}

- (BOOL)isSequenceForCategory:(uint32_t)sequence category:(TJPMessageCategory)category {
    // 提取序列号中的类别部分（高8位）
    uint8_t sequenceCategory = (sequence >> 24) & TJPSEQUENCE_CATEGORY_MASK;
    return sequenceCategory == category;
}


- (void)resetSequence:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);
    _sequences[category] = 0;
    os_unfair_lock_unlock(&_lock);
}

// 重置所有类别的序列号
- (void)resetSequence {
    os_unfair_lock_lock(&_lock);
    memset(_sequences, 0, sizeof(_sequences));
    os_unfair_lock_unlock(&_lock);
}

// 获取类别的当前序列号
- (uint32_t)currentSequenceForCategory:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);
    uint32_t seq = _sequences[category];
    os_unfair_lock_unlock(&_lock);
    return ((uint32_t)category << 24) | seq;
}


@end
