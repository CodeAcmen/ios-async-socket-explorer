//
//  TJPLightweightSessionPool.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/16.
//

#import "TJPLightweightSessionPool.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkCoordinator.h"
#import "TJPNetworkConfig.h"
#import "TJPNetworkDefine.h"

// 默认配置常量
static const TJPSessionPoolConfig kDefaultPoolConfig = {
    .maxPoolSize = 5,           // 每种类型最多5个会话
    .maxIdleTime = 300,         // 5分钟空闲超时
    .cleanupInterval = 60,      // 1分钟清理一次
    .maxReuseCount = 50         // 最多复用50次
};


@interface TJPLightweightSessionPool ()
// 按类型存储的会话池
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<TJPConcreteSession *> *> *sessionPools;
// 活跃会话池
@property (nonatomic, strong) NSMutableSet<TJPConcreteSession *> *activeSessions;
// 池管理队列
@property (nonatomic, strong) dispatch_queue_t poolQueue;

@property (nonatomic, strong) dispatch_source_t cleanupTimer;


// 统计信息
@property (nonatomic, assign) NSUInteger hitCount;
@property (nonatomic, assign) NSUInteger missCount;

// 池状态
@property (nonatomic, assign) BOOL isRunning;

@end

@implementation TJPLightweightSessionPool

#pragma mark - Lifecycle
+ (instancetype)sharedPool {
    static TJPLightweightSessionPool *instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (instancetype)init {
    if (self = [super init]) {
        _config = kDefaultPoolConfig;
        _poolEnabled = YES;
        _isRunning = NO;
        
        _sessionPools = [NSMutableDictionary dictionary];
        _activeSessions = [NSMutableSet set];
        
        _poolQueue = dispatch_queue_create("com.tjp.sessionpool.queue", DISPATCH_QUEUE_SERIAL);
        
        [self setupApplicationNotifications];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma Public Method
- (void)startWithConfig:(TJPSessionPoolConfig)config {
    dispatch_async(self.poolQueue, ^{
        if (self.isRunning) {
            TJPLOG_WARN(@"[SessionPool] 会话池已在运行中");
            return;
        }
        
        self.config = config;
        self.isRunning = YES;
        TJPLOG_INFO(@"[SessionPool] 启动会话池 - 最大池大小:%lu, 空闲超时:%.0f秒, 清理间隔:%.0f秒", (unsigned long)config.maxPoolSize, config.maxIdleTime, config.cleanupInterval);

        [self startCleanupTimer];
    });
}


- (void)stop {
    dispatch_async(self.poolQueue, ^{
        if (!self.isRunning) {
            return;
        }
        
        self.isRunning = NO;
        
        [self stopCleanupTimer];
        
        //断开活跃会话
        for (TJPConcreteSession *session in [self.activeSessions copy]) {
            [session disconnectWithReason:TJPDisconnectReasonUserInitiated];
        }
        [self.activeSessions removeAllObjects];
        
        //清理池中会话
        for (NSNumber *typeKey in [self.sessionPools allKeys]) {
            //获取对应类型的池数组
            NSMutableArray *pool = self.sessionPools[typeKey];
            
            for (TJPConcreteSession *session in [pool copy]) {
                [session disconnectWithReason:TJPDisconnectReasonUserInitiated];
                session.isPooled = NO;
            }
            [pool removeAllObjects];
        }
        [self.sessionPools removeAllObjects];
        TJPLOG_INFO(@"[SessionPool] 会话池已停止");
    });
}

- (void)pause {
    dispatch_async(self.poolQueue, ^{
        self.poolEnabled = NO;
        TJPLOG_INFO(@"[SessionPool] 会话池已暂停");
    });
}

- (void)resume {
    dispatch_async(self.poolQueue, ^{
        self.poolEnabled = YES;
        TJPLOG_INFO(@"[SessionPool] 会话池已恢复");
    });
}

- (id<TJPSessionProtocol>)acquireSessionForType:(TJPSessionType)type withConfig:(TJPNetworkConfig *)config {
    __block TJPConcreteSession *session = nil;
    TJPLOG_INFO(@"[SessionPool] 开始获取会话，类型: %lu", (unsigned long)type);

    //同步获取 确保会话有效
    dispatch_sync(self.poolQueue, ^{
        if (!self.isRunning || !self.poolEnabled) {
            TJPLOG_INFO(@"[SessionPool] 池未启用，创建新会话: %@", session.sessionId);
            //当前池未启用 直接创建新session
            session = [self createNewSessionForType:type withConfig:config];
            if (session) {
                [self.activeSessions addObject:session];
                self.missCount++;
            }
            return;
        }
        
        //尝试从池中获取可复用的会话
        session = [self getReusableSessionForType:type];
        
        if (session) {
            //获取到池
            self.hitCount++;
            //先加入活跃集合 避免提前释放
            [self.activeSessions addObject:session];
            
            //从池中移除 加入活跃列表
            NSMutableArray *pool = [self getPoolForType:type];
            [pool removeObject:session];
            
            session.isPooled = NO;
            session.lastActiveTime = [NSDate date];
            
            //重置session状态 供复用
            [session resetForReuse];
            
            TJPLOG_INFO(@"[SessionPool] 从池中复用会话 %@ (类型:%lu, 使用次数:%lu)", session.sessionId, (unsigned long)type, (unsigned long)session.useCount);
        }else {
            //池未命中，创建新会话
            session = [self createNewSessionForType:type withConfig:config];
            if (session) {
                //加入活跃集合
                [self.activeSessions addObject:session];
                self.missCount++;
                TJPLOG_INFO(@"[SessionPool] 创建新会话 %@ (类型:%lu)", session.sessionId, (unsigned long)type);
            }
        }
        
    });
    
    return session;
}

- (void)releaseSession:(id<TJPSessionProtocol>)session {
    if (!session) {
        TJPLOG_ERROR(@"[SessionPool] releaseSession 收到 nil session");
        return;
    }
    
    if (![session isKindOfClass:[TJPConcreteSession class]]) {
        TJPLOG_WARN(@"[SessionPool] 无法归还非TJPConcreteSession类型的会话: %@", [session class]);
        return;
    }
    TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
    
    // 验证会话完整性
    if (![self validateSession:concreteSession withLabel:@"释放验证"]) {
        TJPLOG_ERROR(@"[SessionPool] 释放的会话验证失败，直接销毁");
        [concreteSession prepareForRelease];
        return;
    }
    
    dispatch_async(self.poolQueue, ^{
        //从活跃列表移除
        [self.activeSessions removeObject:concreteSession];
        
        if (!self.isRunning || !self.poolEnabled) {
            //池未启用，直接断开连接
            [concreteSession disconnectWithReason:TJPDisconnectReasonUserInitiated];
            TJPLOG_INFO(@"[SessionPool] 池未启用，直接断开会话: %@", concreteSession.sessionId);
            return;
        }
        
        //检查会话是否适合放入池中
        if ([self shouldPoolSession:concreteSession]) {
            [self addSessionToPool:concreteSession];
            TJPLOG_INFO(@"[SessionPool] 会话 %@ 已归还到池中 (类型:%lu)", concreteSession.sessionId, (unsigned long)concreteSession.sessionType);
        } else {
            //不适合放入池中，直接断开
            [concreteSession disconnectWithReason:TJPDisconnectReasonUserInitiated];
            TJPLOG_INFO(@"[SessionPool] 会话 %@ 不适合复用，已断开连接", concreteSession.sessionId);
        }
    });
}

- (void)removeSession:(id<TJPSessionProtocol>)session {
    if (![session isKindOfClass:[TJPConcreteSession class]]) {
        return;
    }
    
    TJPConcreteSession *concreteSession = (TJPConcreteSession *)session;
    
    dispatch_async(self.poolQueue, ^{
        //从活跃列表移除
        [self.activeSessions removeObject:concreteSession];
        
        //从池中移除
        NSMutableArray *pool = [self getPoolForType:concreteSession.sessionType];
        [pool removeObject:concreteSession];
        
        //断开连接
        [concreteSession disconnectWithReason:TJPDisconnectReasonUserInitiated];
        concreteSession.isPooled = NO;
        
        TJPLOG_INFO(@"[SessionPool] 强制移除会话 %@", concreteSession.sessionId);
    });
}

- (void)warmupPoolForType:(TJPSessionType)type count:(NSUInteger)count withConfig:(TJPNetworkConfig *)config {
    if (count == 0) return;
    
    dispatch_async(self.poolQueue, ^{
        NSMutableArray *pool = [self getPoolForType:type];
        NSUInteger currentCount = pool.count;
        NSUInteger targetCount = MIN(count, self.config.maxPoolSize);
        
        if (currentCount >= targetCount) {
            TJPLOG_INFO(@"[SessionPool] 类型 %lu 的池已有足够会话，无需预热", (unsigned long)type);
            return;
        }
        
        NSUInteger createCount = targetCount - currentCount;
        TJPLOG_INFO(@"[SessionPool] 开始预热类型 %lu 的会话池，创建 %lu 个会话", (unsigned long)type, (unsigned long)createCount);
        
        for (NSUInteger i = 0; i < createCount; i++) {
            TJPConcreteSession *session = [self createNewSessionForType:type withConfig:config];
            if (!session || !session.sessionId) {
                TJPLOG_ERROR(@"⚠️ [WARMUP] 第%lu个会话创建失败", (unsigned long)(i+1));
                continue;
            }
            
            NSLog(@"🔥 [WARMUP] 创建会话 %@ 准备添加到池", session.sessionId);
            session.isPooled = NO;
            session.lastActiveTime = [NSDate date];
            
            [self addSessionToPool:session];
        }
        
        TJPLOG_INFO(@"[SessionPool] 完成预热，类型 %lu 的池现有 %lu 个会话", (unsigned long)type, (unsigned long)pool.count);
    });
}

#pragma mark - Private Method
- (void)setupApplicationNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

- (TJPConcreteSession *)createNewSessionForType:(TJPSessionType)type withConfig:(TJPNetworkConfig *)config {
    // 如果没有提供配置，使用默认配置
    if (!config) {
        config = [[TJPNetworkCoordinator shared] defaultConfigForSessionType:type];
    }
    
    // 创建会话
    TJPConcreteSession *session = [[TJPConcreteSession alloc] initWithConfiguration:config];
    if (!session) {
        TJPLOG_ERROR(@"[SessionPool] TJPConcreteSession 创建失败，类型: %lu", (unsigned long)type);
        return nil;
    }
    
    // 验证 sessionId 是否有效
    if (!session.sessionId || session.sessionId.length == 0) {
        TJPLOG_ERROR(@"[SessionPool] 新创建的会话 sessionId 无效，重新生成");
        session.sessionId = [[NSUUID UUID] UUIDString];
        
        if (!session.sessionId) {
            TJPLOG_ERROR(@"[SessionPool] 无法生成有效的 sessionId");
            return nil;
        }
    }
    
    
    // 设置属性
    session.sessionType = type;
    session.lastActiveTime = [NSDate date];
    session.useCount = 0;
    session.isPooled = NO;
    
    TJPLOG_INFO(@"[SessionPool] 成功创建新会话: %@，类型: %lu", session.sessionId, (unsigned long)type);
    return session;
}

- (TJPConcreteSession *)getReusableSessionForType:(TJPSessionType)type {
    NSMutableArray *pool = [self getPoolForType:type];
    
    if (!pool || pool.count == 0) {
        TJPLOG_INFO(@"[SessionPool] 类型 %lu 的池为空或不存在", (unsigned long)type);
        return nil;
    }
    
    // 创建数组副本，避免在遍历时修改原数组
    NSArray *poolCopy = [pool copy];
    
    // 寻找最适合复用的会话（空闲时间短且使用次数少的优先）
    TJPConcreteSession *bestSession = nil;
    NSTimeInterval shortestIdleTime = INFINITY;
    NSMutableArray *sessionsToRemove = [NSMutableArray array];

    
    for (TJPConcreteSession *session in poolCopy) {
        // 强引用保持会话，防止在检查过程中被释放
        TJPConcreteSession *strongSession = session;
        
        // 验证会话有效性
        if (!strongSession || !strongSession.sessionId || strongSession.sessionId.length == 0) {
            TJPLOG_INFO(@"[SessionPool] 发现无效会话: %@，标记移除", strongSession.sessionId);
            [sessionsToRemove addObject:strongSession];
            continue;
        }

        // 检查会话健康状况
        @try {
            if (![strongSession isHealthyForReuse]) {
                TJPLOG_INFO(@"[SessionPool] 会话 %@ 健康检查失败，标记移除", strongSession.sessionId);
                [sessionsToRemove addObject:strongSession];
                continue;
            }
        } @catch (NSException *exception) {
            TJPLOG_INFO(@"[SessionPool] 健康检查异常: %@，会话: %@", exception.reason, strongSession.sessionId ?: @"unknown");
            [sessionsToRemove addObject:strongSession];
            continue;
        }
        
        // 计算空闲时间
        NSTimeInterval idleTime = 0;
        @try {
            NSDate *lastActiveTime = strongSession.lastActiveTime;
            if (lastActiveTime) {
                idleTime = [[NSDate date] timeIntervalSinceDate:lastActiveTime];
            }
        } @catch (NSException *exception) {
            TJPLOG_INFO(@"[SessionPool] 计算空闲时间异常: %@", exception.reason);
            [sessionsToRemove addObject:strongSession];
            continue;
        }
        
        // 选择最佳会话
        if (idleTime < shortestIdleTime) {
            shortestIdleTime = idleTime;
            bestSession = strongSession;
        }
        
        TJPLOG_INFO(@"[SessionPool] 会话 %@ 检查通过，空闲时间: %.1f秒", strongSession.sessionId, idleTime);
        
        // 安全移除无效会话
        [self safelyRemoveSessionsFromPool:sessionsToRemove fromPool:pool];
        
        if (bestSession) {
            TJPLOG_INFO(@"[SessionPool] 找到最佳会话: %@，空闲时间: %.1f秒", bestSession.sessionId, shortestIdleTime);
        } else {
            TJPLOG_INFO(@"[SessionPool] 未找到可复用的会话");
        }
    }
    
    return bestSession;
}

- (void)safelyRemoveSessionsFromPool:(NSArray *)sessionsToRemove fromPool:(NSMutableArray *)pool {
    if (sessionsToRemove.count == 0) return;
    
    TJPLOG_INFO(@"[SessionPool] 准备移除 %lu 个无效会话", (unsigned long)sessionsToRemove.count);
    
    for (TJPConcreteSession *session in sessionsToRemove) {
        @try {
            // 安全移除，不触发额外的释放
            if ([pool containsObject:session]) {
                [pool removeObject:session];
                NSLog(@"[SessionPool] 已移除会话: %@", session.sessionId ?: @"unknown");
                
                // 标记为非池状态，但不调用断开
                if (session) {
                    session.isPooled = NO;
                }
            }
        } @catch (NSException *exception) {
            TJPLOG_INFO(@"[SessionPool] 移除会话异常: %@", exception.reason);
        }
    }
}

- (void)startCleanupTimer {
    if (self.cleanupTimer) {
        dispatch_source_cancel(self.cleanupTimer);
    }
    
    self.cleanupTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.poolQueue);
    
    uint64_t interval = (uint64_t)(self.config.cleanupInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(self.cleanupTimer,
                             dispatch_time(DISPATCH_TIME_NOW, interval),
                             interval,
                             (1ull * NSEC_PER_SEC) / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.cleanupTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf performCleanup];
        }
    });
    
    dispatch_resume(self.cleanupTimer);
}

- (void)stopCleanupTimer {
    if (self.cleanupTimer) {
        dispatch_source_cancel(self.cleanupTimer);
        self.cleanupTimer = nil;
    }
}

- (NSMutableArray *)getPoolForType:(TJPSessionType)type {
    // 验证 sessionPools
    if (!self.sessionPools) {
        TJPLOG_ERROR(@"[SessionPool] sessionPools 为 nil，重新初始化");
        self.sessionPools = [NSMutableDictionary dictionary];
    }
    
    NSNumber *typeKey = @(type);
    NSMutableArray *pool = self.sessionPools[typeKey];
    
    if (!pool) {
        pool = [NSMutableArray array];
        self.sessionPools[typeKey] = pool;
        TJPLOG_INFO(@"[SessionPool] 创建类型 %lu 的新池，容量: %lu", (unsigned long)type, (unsigned long)self.config.maxPoolSize);
    }
    
    return pool;
}


- (void)cleanup {
    dispatch_async(self.poolQueue, ^{
        [self performCleanup];
    });
}

- (void)cleanupSessionsForType:(TJPSessionType)type {
    dispatch_async(self.poolQueue, ^{
        [self performCleanupForType:type];
    });
}

- (BOOL)validateSession:(TJPConcreteSession *)session withLabel:(NSString *)label {
    if (!session) {
        TJPLOG_ERROR(@"[SessionPool][%@] 会话为 nil", label);
        return NO;
    }
    
    if (!session.sessionId || session.sessionId.length == 0) {
        TJPLOG_ERROR(@"[SessionPool][%@] 会话 sessionId 无效", label);
        return NO;
    }
    
    if (![session isKindOfClass:[TJPConcreteSession class]]) {
        TJPLOG_ERROR(@"[SessionPool][%@] 会话类型错误: %@", label, [session class]);
        return NO;
    }
    
    TJPLOG_INFO(@"[SessionPool][%@] 会话验证通过: %@", label, session.sessionId);
    return YES;
}

- (BOOL)shouldPoolSession:(TJPConcreteSession *)session {
    //检查池是否已满
    NSMutableArray *pool = [self getPoolForType:session.sessionType];
    if (pool.count >= self.config.maxPoolSize) {
        return NO;
    }
    
    //检查会话健康状况
    if (![session isHealthyForReuse]) {
        return NO;
    }
    
    //检查使用次数
    if (session.useCount >= self.config.maxReuseCount) {
        return NO;
    }
    
    //检查连接状态
    if (session.connectState != TJPConnectStateConnected) {
        return NO;
    }
    
    return YES;
}

- (void)addSessionToPool:(TJPConcreteSession *)session {
    // 验证 session 不为 nil
    if (!session) {
        TJPLOG_ERROR(@"[SessionPool] addSessionToPool 收到 nil session，调用栈检查");
        
        // 调试：打印调用栈
        NSArray *callStack = [NSThread callStackSymbols];
        for (NSString *frame in callStack) {
            TJPLOG_ERROR(@"📞 [SessionPool] %@", frame);
        }
        return;
    }
    
    // 验证 sessionId
    if (!session.sessionId || session.sessionId.length == 0) {
        TJPLOG_ERROR(@"[SessionPool] 会话 sessionId 无效，不能添加到池中");
        return;
    }
    
    // 验证 sessionType
    if (session.sessionType < 0) {
        TJPLOG_ERROR(@"[SessionPool] 会话类型无效: %ld", (long)session.sessionType);
        return;
    }
    
    // 验证 sessionPools
    if (!self.sessionPools) {
        TJPLOG_ERROR(@"[SessionPool] sessionPools 字典为 nil，重新初始化");
        self.sessionPools = [NSMutableDictionary dictionary];
    }
    
    NSMutableArray *pool = [self getPoolForType:session.sessionType];
    
    // 验证获取到的池
    if (!pool) {
        TJPLOG_ERROR(@"[SessionPool] 无法获取类型 %lu 的池", (unsigned long)session.sessionType);
        return;
    }
    
    // 检查池是否已满
    if (pool.count >= self.config.maxPoolSize) {
        TJPLOG_INFO(@"[SessionPool] 类型 %lu 的池已满，移除最旧会话", (unsigned long)session.sessionType);
        TJPConcreteSession *oldestSession = [pool firstObject];
        if (oldestSession) {
            [pool removeObject:oldestSession];
            [oldestSession prepareForRelease];
        }
    }
    
    // 检查是否已在池中
    if ([pool containsObject:session]) {
        TJPLOG_WARN(@"[SessionPool] 会话 %@ 已在池中，跳过添加", session.sessionId);
        return;
    }
    
    session.isPooled = YES;
    session.lastReleaseTime = [NSDate date];
    
    // try-catch 防护
    @try {
        [pool addObject:session];
        TJPLOG_INFO(@"[SessionPool] 成功添加会话 %@ 到类型 %lu 的池中，池大小: %lu/%lu",
                   session.sessionId, (unsigned long)session.sessionType,
                   (unsigned long)pool.count, (unsigned long)self.config.maxPoolSize);
    } @catch (NSException *exception) {
        TJPLOG_ERROR(@"[SessionPool] 添加会话到池异常: %@, 会话: %@", exception.reason, session.sessionId ?: @"unknown");
        // 重置会话状态
        session.isPooled = NO;
        session.lastReleaseTime = nil;
    }
    
}

- (void)performCleanup {
    NSUInteger totalCleaned = 0;
    
    for (NSNumber *typeKey in [self.sessionPools allKeys]) {
        totalCleaned += [self performCleanupForType:[typeKey unsignedIntegerValue]];
    }
    
    if (totalCleaned > 0) {
        TJPLOG_INFO(@"[SessionPool] 清理完成，共移除 %lu 个过期会话", (unsigned long)totalCleaned);
    }
}

- (NSUInteger)performCleanupForType:(TJPSessionType)type {
    NSMutableArray *pool = [self getPoolForType:type];
    NSMutableArray *sessionsToRemove = [NSMutableArray array];
    
    NSDate *now = [NSDate date];
    
    for (TJPConcreteSession *session in [pool copy]) {
        BOOL shouldRemove = NO;
        
        // 检查空闲时间
        NSTimeInterval idleTime = [now timeIntervalSinceDate:session.lastReleaseTime ?: session.lastActiveTime];
        if (idleTime > self.config.maxIdleTime) {
            TJPLOG_INFO(@"[SessionPool] 会话 %@ 空闲时间过长(%.0f秒)，移除", session.sessionId, idleTime);
            shouldRemove = YES;
        }
        
        // 检查健康状况
        if (![session isHealthyForReuse]) {
            TJPLOG_INFO(@"[SessionPool] 会话 %@ 健康检查失败，移除", session.sessionId);
            shouldRemove = YES;
        }
        
        if (shouldRemove) {
            [sessionsToRemove addObject:session];
        }
    }
    
    // 移除无效会话
    for (TJPConcreteSession *session in sessionsToRemove) {
        [pool removeObject:session];
        [session disconnectWithReason:TJPDisconnectReasonIdleTimeout];
        session.isPooled = NO;
    }
    
    return sessionsToRemove.count;
}


#pragma mark - Analysis
- (TJPSessionPoolStats)getPoolStats {
    __block TJPSessionPoolStats stats = {0};
    
    dispatch_sync(self.poolQueue, ^{
        stats.activeSessions = self.activeSessions.count;
        
        for (NSMutableArray *pool in self.sessionPools.allValues) {
            stats.pooledSessions += pool.count;
        }
        
        stats.totalSessions = stats.activeSessions + stats.pooledSessions;
        stats.hitCount = self.hitCount;
        stats.missCount = self.missCount;
        
        NSUInteger totalRequests = self.hitCount + self.missCount;
        stats.hitRate = totalRequests > 0 ? (double)self.hitCount / totalRequests : 0.0;
    });
    
    return stats;
}

- (NSUInteger)getSessionCountForType:(TJPSessionType)type {
    __block NSUInteger count = 0;
    
    dispatch_sync(self.poolQueue, ^{
        // 统计活跃会话
        for (TJPConcreteSession *session in self.activeSessions) {
            if (session.sessionType == type) {
                count++;
            }
        }
        
        // 统计池中会话
        NSMutableArray *pool = self.sessionPools[@(type)];
        count += pool.count;
    });
    
    return count;
}

- (NSUInteger)getPooledSessionCountForType:(TJPSessionType)type {
    __block NSUInteger count = 0;
    
    dispatch_sync(self.poolQueue, ^{
        NSMutableArray *pool = self.sessionPools[@(type)];
        count = pool.count;
    });
    
    return count;
}

- (void)resetStats {
    dispatch_async(self.poolQueue, ^{
        self.hitCount = 0;
        self.missCount = 0;
        TJPLOG_INFO(@"[SessionPool] 已重置会话池统计信息");
    });
}


#pragma mark - Notifications
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    dispatch_async(self.poolQueue, ^{
        TJPLOG_INFO(@"[SessionPool] 应用进入后台，暂停会话池清理");
        [self stopCleanupTimer];
        
        // 可选：断开部分非关键会话以节省资源
        // [self cleanupNonCriticalSessions];
    });
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    dispatch_async(self.poolQueue, ^{
        if (self.isRunning) {
            TJPLOG_INFO(@"[SessionPool] 应用回到前台，恢复会话池清理");
            [self startCleanupTimer];
            
            // 立即执行一次清理
            [self performCleanup];
        }
    });
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stop];
}


#pragma mark - Debug

- (void)logPoolStatus {
    dispatch_async(self.poolQueue, ^{
        TJPSessionPoolStats stats = [self getPoolStats];
        
        TJPLOG_INFO(@"=== 会话池状态 ===");
        TJPLOG_INFO(@"池状态: %@", self.isRunning ? @"运行中" : @"已停止");
        TJPLOG_INFO(@"池功能: %@", self.poolEnabled ? @"启用" : @"禁用");
        TJPLOG_INFO(@"总会话数: %lu", (unsigned long)stats.totalSessions);
        TJPLOG_INFO(@"活跃会话: %lu", (unsigned long)stats.activeSessions);
        TJPLOG_INFO(@"池中会话: %lu", (unsigned long)stats.pooledSessions);
        TJPLOG_INFO(@"命中率: %.2f%% (%lu/%lu)", stats.hitRate * 100, (unsigned long)stats.hitCount, (unsigned long)(stats.hitCount + stats.missCount));
        
        for (NSNumber *typeKey in [self.sessionPools allKeys]) {
            TJPSessionType type = [typeKey unsignedIntegerValue];
            NSUInteger poolCount = [self getPooledSessionCountForType:type];
            NSUInteger totalCount = [self getSessionCountForType:type];
            TJPLOG_INFO(@"类型 %lu: 总计 %lu, 池中 %lu", (unsigned long)type, (unsigned long)totalCount, (unsigned long)poolCount);
        }
        TJPLOG_INFO(@"================");
    });
}

- (NSDictionary *)getDetailedPoolInfo {
    __block NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.poolQueue, ^{
        TJPSessionPoolStats stats = [self getPoolStats];
        
        info[@"isRunning"] = @(self.isRunning);
        info[@"poolEnabled"] = @(self.poolEnabled);
        info[@"config"] = @{
            @"maxPoolSize": @(self.config.maxPoolSize),
            @"maxIdleTime": @(self.config.maxIdleTime),
            @"cleanupInterval": @(self.config.cleanupInterval),
            @"maxReuseCount": @(self.config.maxReuseCount)
        };
        info[@"stats"] = @{
            @"totalSessions": @(stats.totalSessions),
            @"activeSessions": @(stats.activeSessions),
            @"pooledSessions": @(stats.pooledSessions),
            @"hitCount": @(stats.hitCount),
            @"missCount": @(stats.missCount),
            @"hitRate": @(stats.hitRate)
        };
        
        NSMutableDictionary *typeInfo = [NSMutableDictionary dictionary];
        for (NSNumber *typeKey in [self.sessionPools allKeys]) {
            TJPSessionType type = [typeKey unsignedIntegerValue];
            typeInfo[typeKey] = @{
                @"pooledCount": @([self getPooledSessionCountForType:type]),
                @"totalCount": @([self getSessionCountForType:type])
            };
        }
        info[@"typeBreakdown"] = typeInfo;
    });
    
    return [info copy];
}

@end
