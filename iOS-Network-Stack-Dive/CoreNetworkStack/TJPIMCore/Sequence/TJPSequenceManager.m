//
//  TJPSequenceManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPSequenceManager.h"
#import <os/lock.h>
#import "TJPNetworkDefine.h"

@interface TJPSequenceManager ()

@property (nonatomic, copy, readwrite) NSString *sessionId;
@property (nonatomic, assign) uint32_t sessionSeed;  // 会话种子，用于避免不同会话间冲突

@end

@implementation TJPSequenceManager {
    //根据类型对序列号分区
    uint32_t _sequences[4];
    os_unfair_lock _lock;
    
    // 统计信息
    uint64_t _totalGenerated[4];    // 每个类别生成的总数
    NSDate *_lastResetTime[4];      // 每个类别最后重置时间
}

- (instancetype)initWithSessionId:(NSString *)sessionId {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _sessionId = sessionId;
        
        //基于sessionId生成种子，确保不同会话的序列号有差异
        _sessionSeed = [self generateSessionSeed:_sessionId];
        
        //初始化序列号（从种子开始，避免从0开始）
        [self initializeSequences];
        
        //初始化统计信息
        memset(_totalGenerated, 0, sizeof(_totalGenerated));
        for (int i = 0; i < 4; i++) {
            _lastResetTime[i] = [NSDate date];
        }
    }
    return self;
}

- (void)initializeSequences {
    os_unfair_lock_lock(&_lock);
    
    //使用会话种子初始化，避免所有会话都从0开始
    for (int i = 0; i < 4; i++) {
        _sequences[i] = (_sessionSeed + i * 1000) & TJPSEQUENCE_BODY_MASK;
        // 确保不会太接近最大值
        if (_sequences[i] > TJPSEQUENCE_RESET_THRESHOLD) {
            _sequences[i] = _sequences[i] % 10000;
        }
    }
    
    os_unfair_lock_unlock(&_lock);
}

- (uint32_t)nextSequenceForCategory:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);

    //获取目标类别的当前序列号
    uint32_t *categorySequence = &_sequences[category];
    
    //计算新序列号:类别8位 + 24位序列号
    *categorySequence = (*categorySequence + 1) & TJPSEQUENCE_BODY_MASK;
    
    //更新统计
    _totalGenerated[category]++;
    
    
    //增加最大值判断
    if (*categorySequence > TJPSEQUENCE_WARNING_THRESHOLD) {
        //接近最大值时警告
        if (self.sequenceResetHandler) {
            NSString *sessionId = [_sessionId copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sequenceResetHandler(category);
            });
            
            TJPLOG_WARN(@"[TJPSequenceManager] 会话 %@ 类别 %d 序列号接近上限: %u", sessionId, (int)category, *categorySequence);
        }
    }
    
    //检查是否需要重置（提前重置，避免到达真正的最大值）

    if (*categorySequence >= TJPSEQUENCE_RESET_THRESHOLD) {
        TJPLOG_INFO(@"[TJPSequenceManager] 会话 %@ 类别 %d 序列号重置: %u -> 0", _sessionId, (int)category, *categorySequence);

        *categorySequence = 0;
        _lastResetTime[category] = [NSDate date];

        // 通知重置事件
        if (self.sequenceResetHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sequenceResetHandler(category);
            });
        }
    }
    
    
    //通过与上掩码取出24位序列号
    uint32_t nextSeq = ((uint32_t)category << TJPSEQUENCE_BODY_BITS) | *categorySequence;
    
    os_unfair_lock_unlock(&_lock);
    
    return nextSeq;
}

- (BOOL)isSequenceForCategory:(uint32_t)sequence category:(TJPMessageCategory)category {
    // 提取序列号中的类别部分（高8位）
    uint8_t sequenceCategory = (sequence >> TJPSEQUENCE_BODY_BITS) & TJPSEQUENCE_CATEGORY_MASK;
    return sequenceCategory == category;
}


- (void)resetSequence:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);
    _sequences[category] = 0;
    _lastResetTime[category] = [NSDate date];
    os_unfair_lock_unlock(&_lock);
    TJPLOG_INFO(@"[TJPSequenceManager] 手动重置会话 %@ 类别 %d 序列号", _sessionId, (int)category);
}

// 重置所有类别的序列号
- (void)resetSequence {
    os_unfair_lock_lock(&_lock);
    memset(_sequences, 0, sizeof(_sequences));
    for (int i = 0; i < 4; i++) {
        _lastResetTime[i] = [NSDate date];
    }
    os_unfair_lock_unlock(&_lock);
    TJPLOG_INFO(@"[TJPSequenceManager] 手动重置会话 %@ 所有序列号", _sessionId);
}

// 获取类别的当前序列号
- (uint32_t)currentSequenceForCategory:(TJPMessageCategory)category {
    os_unfair_lock_lock(&_lock);
    uint32_t seq = _sequences[category];
    os_unfair_lock_unlock(&_lock);
    
    return ((uint32_t)category << TJPSEQUENCE_BODY_BITS) | seq;
}

- (uint32_t)currentRawSequenceForCategory:(TJPMessageCategory)category {
    
    os_unfair_lock_lock(&_lock);
    uint32_t seq = _sequences[category];
    os_unfair_lock_unlock(&_lock);
    
    return seq;
}

- (uint32_t)generateSessionSeed:(NSString *)sessionId {
    // 简单的hash算法，将sessionId转换为种子
    uint32_t hash = 5381;
    const char *str = [sessionId UTF8String];
    while (*str) {
        hash = ((hash << 5) + hash) + *str++;
    }
    return hash & TJPSEQUENCE_BODY_MASK;
}

// 检查序列号是否在安全范围内
- (BOOL)isSequenceInSafeRange:(TJPMessageCategory)category {
    
    os_unfair_lock_lock(&_lock);
    uint32_t seq = _sequences[category];
    os_unfair_lock_unlock(&_lock);
    
    return seq < TJPSEQUENCE_WARNING_THRESHOLD;
}

- (NSDictionary *)getStatistics {
    os_unfair_lock_lock(&_lock);
    
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    stats[@"sessionId"] = _sessionId;
    stats[@"sessionSeed"] = @(_sessionSeed);
    
    for (int i = 0; i < 4; i++) {
        NSString *categoryKey = [NSString stringWithFormat:@"category_%d", i];
        stats[categoryKey] = @{
            @"current": @(_sequences[i]),
            @"total_generated": @(_totalGenerated[i]),
            @"last_reset": _lastResetTime[i],
            @"utilization": @((double)_sequences[i] / TJPSEQUENCE_MAX_VALUE * 100),
            @"safe": @(_sequences[i] < TJPSEQUENCE_WARNING_THRESHOLD)
        };
    }
    
    os_unfair_lock_unlock(&_lock);
    
    return [stats copy];
}

// 新增：健康检查
- (BOOL)isHealthy {
    for (int i = 0; i < 4; i++) {
        if (![self isSequenceInSafeRange:i]) {
            return NO;
        }
    }
    return YES;
}

// 新增：预测下次重置时间
- (NSTimeInterval)estimateTimeToResetForCategory:(TJPMessageCategory)category
                                 averageQPS:(double)qps {
    if (category >= 4 || qps <= 0) return -1;
    
    os_unfair_lock_lock(&_lock);
    uint32_t current = _sequences[category];
    os_unfair_lock_unlock(&_lock);
    
    uint32_t remaining = TJPSEQUENCE_RESET_THRESHOLD - current;
    return remaining / qps;
}

@end
