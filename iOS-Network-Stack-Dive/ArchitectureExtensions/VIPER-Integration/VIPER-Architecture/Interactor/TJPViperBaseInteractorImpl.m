//
//  TJPViperBaseInteractorImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseInteractorImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPViperDefaultErrorHandler.h"
#import "TJPMemoryCache.h"
#import "TJPPaginationInfo.h"

@interface TJPViperBaseInteractorImpl ()

@property (nonatomic, strong) TJPCacheManager *cacheManager;
@property (nonatomic, strong) TJPViperDefaultErrorHandler *errorHandler;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *uploadProgressMap;
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedTopics;


// 分页相关属性
@property (nonatomic, strong) TJPPaginationInfo *currentPagination;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL hasMoreData;

@end


@implementation TJPViperBaseInteractorImpl
@synthesize navigateToPageSubject = _navigateToPageSubject, dataListUpdatedSignal = _dataListUpdatedSignal;

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        // 缓存组件
        _cacheManager = [[TJPCacheManager alloc] initWithCacheStrategy:[[TJPMemoryCache alloc] init]];

        // 错误处理组件
        _errorHandler = [TJPViperDefaultErrorHandler sharedHandler];
        
        _requestTimeout = 30.0;
        _maxRetryCount = 3;
        _isInitialized = NO;
        _uploadProgressMap = [NSMutableDictionary dictionary];
        _subscribedTopics = [NSMutableSet set];
        
        // 分页相关初始化
        _defaultPageSize = 10;
        _currentPage = 0;
        _hasMoreData = YES;
        _currentPagination = nil;
        
        [self setupInteractor];
        _isInitialized = YES;
        
        TJPLOG_INFO(@"[%@] Interactor 初始化完成", NSStringFromClass([self class]));
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
    [self teardownInteractor];
}

#pragma mark - Subject
- (RACSubject *)navigateToPageSubject {
    if (!_navigateToPageSubject) {
        _navigateToPageSubject = [RACSubject subject];
    }
    return _navigateToPageSubject;
}


- (RACSubject<NSDictionary *> *)dataListUpdatedSignal {
    if (!_dataListUpdatedSignal) {
        _dataListUpdatedSignal = [RACSubject subject];
    }
    return _dataListUpdatedSignal;
}


#pragma mark - Load Data
- (void)fetchDataForPageWithCompletion:(NSInteger)page success:(void (^)(NSArray * _Nullable, NSInteger))success failure:(void (^)(NSError * _Nullable))failure {
    // 调用新方法并适配旧接口
    [self fetchDataForPageWithPagination:page success:^(NSArray * _Nullable data, TJPPaginationInfo * _Nullable pagination) {
        if (success) {
            NSInteger totalPage = pagination.paginationType == TJPPaginationTypePageBased ? pagination.totalPages : 0;
            success(data, totalPage);
        }
    } failure:failure];
}

- (void)fetchDataForPageWithPagination:(NSInteger)page
                               success:(void (^)(NSArray * _Nullable, TJPPaginationInfo * _Nullable))success
                               failure:(void (^)(NSError * _Nullable))failure {
    
    TJPLOG_INFO(@"[%@] 开始请求第 %ld 页数据（带分页信息）", NSStringFromClass([self class]), (long)page);

    // 参数验证
    if (page <= 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"页码必须大于0"}];
        if (failure) failure(error);
        return;
    }
    
    // 检查是否可以加载下一页
    if (page > 1 && _currentPagination && !_currentPagination.canLoadNextPage) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"没有更多数据"}];
        if (failure) failure(error);
        return;
    }
    
    // 检查缓存
    NSString *cacheKey = [self cacheKeyForPage:page];
    NSString *paginationCacheKey = [self paginationCacheKeyForPage:page];
    
    NSArray *cachedData = [self.cacheManager loadCacheForKey:cacheKey];
    TJPPaginationInfo *cachedPagination = [self loadCachedPaginationForPage:page];
    
    if (cachedData && cachedPagination) {
        TJPLOG_INFO(@"[%@] 返回第 %ld 页缓存数据", NSStringFromClass([self class]), (long)page);
        [self updatePaginationInfo:cachedPagination];
        if (success) success(cachedData, cachedPagination);
        return;
    }
    
    // 如果是基类被直接调用，抛出错误
    if ([self isMemberOfClass:[TJPViperBaseInteractorImpl class]]) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"子类必须重写此方法"}];
        if (failure) failure(error);
        return;
    }

    // 执行具体的数据请求（由子类实现）
    [self performDataRequestForPage:page withPagination:^(NSArray *data, TJPPaginationInfo *pagination, NSError *error) {
        if (error) {
            TJPLOG_ERROR(@"数据请求失败: %@", error.localizedDescription);
            if (failure) failure(error);
        } else {
            TJPLOG_INFO(@"数据请求成功: %lu 条数据", (unsigned long)data.count);

            // 更新分页信息
            if (pagination) {
                [self updatePaginationInfo:pagination];
            }

            // 缓存数据和分页信息
            if ([self shouldCacheDataForPage:page] && data.count > 0) {
                [self.cacheManager saveCacheWithData:data forKey:cacheKey expireTime:TJPCacheExpireTimeMedium];
                if (pagination) {
                    [self cachePaginationInfo:pagination forPage:page];
                }
            }
            
            if (success) success(data, pagination);
        }
    }];
}

#pragma mark - Manage Data
- (void)createData:(NSDictionary *)data completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 创建数据: %@", NSStringFromClass([self class]), data);

    // 业务规则验证
    NSError *validationError = [self validateBusinessRules:data];
    if (validationError) {
        if (completion) completion(nil, validationError);
        return;
    }
    
    // 基类提供默认实现，子类可重写
    // 这里可以是模拟实现或者调用通用的创建API
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *result = @{
            @"id": [[NSUUID UUID] UUIDString],
            @"status": @"created",
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        if (completion) completion(result, nil);
        
        // 发送数据更新信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"create", @"data": result}];
    });
}

- (void)updateDataWithId:(NSString *)dataId updateData:(NSDictionary *)updateData completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 更新数据，ID: %@", NSStringFromClass([self class]), dataId);

    if (!dataId || dataId.length == 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorDataInvalid
                                         userInfo:@{NSLocalizedDescriptionKey: @"数据ID不能为空"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *result = @{
            @"id": dataId,
            @"status": @"updated",
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        if (completion) completion(result, nil);
        
        // 发送数据更新信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"update", @"id": dataId, @"data": result}];
    });
}

- (void)deleteDataWithId:(NSString *)dataId completion:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 删除数据，ID: %@", NSStringFromClass([self class]), dataId);

    if (!dataId || dataId.length == 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorDataInvalid
                                         userInfo:@{NSLocalizedDescriptionKey: @"数据ID不能为空"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 发送数据更新信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"delete", @"id": dataId}];
    });
}

- (void)searchDataWithKeyword:(NSString *)keyword filters:(NSDictionary *)filters completion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 搜索数据，关键词: %@, 筛选条件: %@",  NSStringFromClass([self class]), keyword, filters);

    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 模拟搜索结果
        NSMutableArray *results = [NSMutableArray array];
        
        if (keyword && keyword.length > 0) {
            [results addObject:@{
                @"id": @"search_1",
                @"title": [NSString stringWithFormat:@"搜索结果: %@", keyword],
                @"type": @"search_result"
            }];
        }
        
        if (completion) completion([results copy], nil);
    });
}

- (TJPPaginationInfo * _Nullable)extractPaginationFromResponse:(id)rawData {
    // 基类提供默认实现，子类可重写
    if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)rawData;
        NSDictionary *paginationDict = dict[@"pagination"] ?: dict[@"page_info"] ?: dict[@"paging"];
        
        if (paginationDict) {
            return [TJPPaginationInfo paginationWithDict:paginationDict];
        }
    }
    return nil;
}

#pragma mark - Manage Cache
- (NSString *)paginationCacheKeyForPage:(NSInteger)page {
    return [NSString stringWithFormat:@"%@_pagination_page_%ld", NSStringFromClass([self class]), (long)page];
}

- (void)cachePaginationInfo:(TJPPaginationInfo *)pagination forPage:(NSInteger)page {
    NSString *cacheKey = [self paginationCacheKeyForPage:page];
    NSDictionary *paginationDict = [pagination toDictionary];
    [self.cacheManager saveCacheWithData:paginationDict forKey:cacheKey expireTime:TJPCacheExpireTimeMedium];
    
    TJPLOG_INFO(@"[%@] 缓存第 %ld 页分页信息", NSStringFromClass([self class]), (long)page);
}

- (TJPPaginationInfo * _Nullable)loadCachedPaginationForPage:(NSInteger)page {
    NSString *cacheKey = [self paginationCacheKeyForPage:page];
    NSDictionary *cachedDict = [self.cacheManager loadCacheForKey:cacheKey];
    
    if (cachedDict && [cachedDict isKindOfClass:[NSDictionary class]]) {
        TJPLOG_INFO(@"[%@] 加载第 %ld 页缓存分页信息", NSStringFromClass([self class]), (long)page);
        return [TJPPaginationInfo paginationWithDict:cachedDict];
    }
    
    return nil;
}

- (void)clearCache:(NSString *)cacheKey {
    TJPLOG_INFO(@"[%@] 清理缓存，缓存键: %@", NSStringFromClass([self class]), cacheKey);
    [self.cacheManager removeCacheForKey:cacheKey];
    
    // 同时清理对应的分页缓存
    if ([cacheKey containsString:@"_page_"]) {
        NSString *paginationCacheKey = [cacheKey stringByReplacingOccurrencesOfString:@"_page_" withString:@"_pagination_page_"];
        [self.cacheManager removeCacheForKey:paginationCacheKey];
    }
}

- (void)clearAllCache {
    TJPLOG_INFO(@"[%@] 清理所有缓存", NSStringFromClass([self class]));
    [self.cacheManager clearAllCache];
    [self resetPagination]; // 同时重置分页信息
}

- (NSUInteger)getCacheSize {
    // 实际项目中可以实现更精确的计算
    return 1024 * 1024 * 3; // 3MB
}

#pragma mark - Manage State

- (void)syncDataToServer:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 正在同步数据到服务器", NSStringFromClass([self class]));

    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 发送同步完成信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"sync_to_server", @"status": @"completed"}];
    });
}

- (void)syncDataFromServer:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 正在同步数据从服务器", NSStringFromClass([self class]));

    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 发送同步完成信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"sync_from_server", @"status": @"completed"}];
    });
}

#pragma mark - Option Method
- (void)subscribeToRealTimeData:(NSString *)topic completion:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 订阅实时数据: %@", NSStringFromClass([self class]), topic);

    if (!topic || topic.length == 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorDataInvalid
                                         userInfo:@{NSLocalizedDescriptionKey: @"订阅主题不能为空"}];
        if (completion) completion(NO, error);
        return;
    }
    
    [self.subscribedTopics addObject:topic];
    
    // 模拟订阅成功
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 模拟实时数据推送
        [self simulateRealTimeDataForTopic:topic];
    });
}

- (void)unsubscribeFromRealTimeData:(NSString *)topic {
    TJPLOG_INFO(@"[%@] 取消订阅实时数据: %@", NSStringFromClass([self class]), topic);
    [self.subscribedTopics removeObject:topic];
}

- (void)uploadFile:(NSData *)fileData fileName:(NSString *)fileName progress:(void (^)(CGFloat))progress completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] 正在上传文件: %@, 大小: %lu 字节", NSStringFromClass([self class]), fileName, (unsigned long)fileData.length);

    if (!fileData || !fileName) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorDataInvalid
                                         userInfo:@{NSLocalizedDescriptionKey: @"文件数据或文件名不能为空"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // 模拟文件上传进度 调用实际项目中的网络框架上传
    __block CGFloat currentProgress = 0.0;
    NSString *uploadId = [[NSUUID UUID] UUIDString];
    self.uploadProgressMap[uploadId] = @(currentProgress);
    
    NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        currentProgress += 0.1;
        self.uploadProgressMap[uploadId] = @(currentProgress);
        
        if (progress) progress(currentProgress);
        
        if (currentProgress >= 1.0) {
            [timer invalidate];
            [self.uploadProgressMap removeObjectForKey:uploadId];
            
            // 模拟上传完成
            NSString *fileUrl = [NSString stringWithFormat:@"https://cdn.example.com/files/%@", fileName];
            if (completion) completion(fileUrl, nil);
            
            // 发送上传完成信号
            [self.dataListUpdatedSignal sendNext:@{
                @"action": @"file_uploaded",
                @"fileName": fileName,
                @"fileUrl": fileUrl
            }];
        }
    }];
}

- (id _Nullable)getConfigValue:(NSString *)configKey {
    // 模拟配置获取，子类可重写
    static NSDictionary *configs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        configs = @{
            @"api_base_url": @"https://api.example.com",
            @"max_retry_count": @3,
            @"request_timeout": @30.0,
            @"cache_expire_time": @(TJPCacheExpireTimeMedium),
            @"enable_debug": @YES,
            @"max_upload_size": @(10 * 1024 * 1024) // 10MB
        };
    });
    
    return configs[configKey];
}

- (NSError * _Nullable)validateBusinessRules:(NSDictionary *)data {
    // 基础业务规则验证，子类可重写
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        return [NSError errorWithDomain:TJPViperErrorDomain
                                   code:TJPViperErrorDataInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"数据格式错误"}];
    }
    
    return nil; // 验证通过
}

#pragma mark - Abstract Methods
- (void)performDataRequestForPage:(NSInteger)page
                       completion:(void (^)(NSArray * _Nullable, NSInteger, NSError * _Nullable))completion {
    // 调用新的带分页信息的方法
    [self performDataRequestForPage:page withPagination:^(NSArray * _Nullable data, TJPPaginationInfo * _Nullable pagination, NSError * _Nullable error) {
        if (completion) {
            NSInteger totalPage = pagination && pagination.paginationType == TJPPaginationTypePageBased ? pagination.totalPages : 0;
            completion(data, totalPage, error);
        }
    }];
}

- (void)performDataRequestForPage:(NSInteger)page
                   withPagination:(void (^)(NSArray * _Nullable, TJPPaginationInfo * _Nullable, NSError * _Nullable))completion {
    // 这是新的抽象方法，子类必须实现
    NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                         code:TJPViperErrorBusinessLogicFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"子类必须实现performDataRequestForPage:withPagination:方法"}];
    if (completion) completion(nil, nil, error);
}

#pragma mark - Methods for Subclass Override
- (NSString *)baseURLString {
    return @"https://api.example.com";
}

- (NSDictionary *)commonParameters {
    return @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"version": @"1.0",
        @"platform": @"ios"
    };
}

- (NSDictionary *)parametersForPage:(NSInteger)page {
    NSMutableDictionary *params = [[self commonParameters] mutableCopy];
    params[@"page"] = @(page);
    params[@"pageSize"] = @(20);
    return [params copy];
}

- (NSArray *)processRawResponseData:(id)rawData {
    if ([rawData isKindOfClass:[NSArray class]]) {
        return (NSArray *)rawData;
    } else if ([rawData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)rawData;
        return dict[@"data"] ?: dict[@"list"] ?: dict[@"items"] ?: @[];
    }
    return @[];
}

- (NSError * _Nullable)validateResponseData:(id)rawData {
    if (!rawData) {
        return [NSError errorWithDomain:TJPViperErrorDomain
                                   code:TJPViperErrorDataEmpty
                               userInfo:@{NSLocalizedDescriptionKey: @"服务器返回空数据"}];
    }
    return nil;
}

#pragma mark - Utility Methods

- (NSString *)cacheKeyForPage:(NSInteger)page {
    return [NSString stringWithFormat:@"%@_page_%ld", NSStringFromClass([self class]), (long)page];
}

- (BOOL)shouldCacheDataForPage:(NSInteger)page {
    return page <= 10; // 默认对前10页进行缓存
}

- (void)setupInteractor {
    // 子类可重写此方法进行初始化设置
}

- (void)teardownInteractor {
    // 清理订阅
    [self.subscribedTopics removeAllObjects];
    
    // 清理上传进度
    [self.uploadProgressMap removeAllObjects];
    
    // 清理分页信息
    [self resetPagination];

    
    // 子类可重写此方法进行清理工作
}

#pragma mark - Pagination Management
- (void)resetPagination {
    _currentPage = 0;
    _hasMoreData = YES;
    _currentPagination = nil;
    
    TJPLOG_INFO(@"[%@] 分页信息已重置", NSStringFromClass([self class]));
}

- (void)updatePaginationInfo:(TJPPaginationInfo *)paginationInfo {
    _currentPagination = [paginationInfo copy];
    
    if (paginationInfo.paginationType == TJPPaginationTypePageBased) {
        _currentPage = paginationInfo.currentPage;
        _hasMoreData = paginationInfo.hasMore;
    } else {
        // 游标分页时，currentPage 用于记录已加载的页面数
        _currentPage = _currentPage > 0 ? _currentPage : 1;
        _hasMoreData = paginationInfo.hasMore;
    }
    
    TJPLOG_INFO(@"[%@] 分页信息已更新: %@", NSStringFromClass([self class]), paginationInfo.debugDescription);
}

- (BOOL)canLoadNextPage {
    NSLog(@"[DEBUG] canLoadNextPage: hasMoreData=%@, currentPage=%ld", _hasMoreData ? @"YES" : @"NO", (long)self.currentPage);
    return _hasMoreData && _currentPagination.canLoadNextPage;
}

- (NSInteger)getNextPageNumber {
    NSInteger nextPage;
    if (!_currentPagination) {
        nextPage = 1;
    } else if (_currentPagination.paginationType == TJPPaginationTypePageBased) {
        nextPage = _currentPagination.getNextPageNumber;
    } else {
        nextPage = _currentPage + 1;
    }
    
    NSLog(@"[DEBUG] getNextPageNumber: currentPage=%ld, nextPage=%ld", (long)_currentPage, (long)nextPage);
    NSLog(@"[DEBUG] 调用栈: %@", [NSThread callStackSymbols]);
    
    return nextPage;
}


#pragma mark - Private Methods

- (void)simulateRealTimeDataForTopic:(NSString *)topic {
    // 模拟实时数据推送
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.subscribedTopics containsObject:topic]) {
            NSDictionary *realTimeData = @{
                @"topic": topic,
                @"data": @{
                    @"message": [NSString stringWithFormat:@"实时数据更新: %@", topic],
                    @"timestamp": @([[NSDate date] timeIntervalSince1970])
                },
                @"type": @"real_time_update"
            };
            
            [self.dataListUpdatedSignal sendNext:realTimeData];
        }
    });
}

- (NSError *)createErrorWithCode:(TJPViperError)errorCode description:(NSString *)description {
    return [NSError errorWithDomain:TJPViperErrorDomain
                               code:errorCode
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"未知错误"}];
}


@end
