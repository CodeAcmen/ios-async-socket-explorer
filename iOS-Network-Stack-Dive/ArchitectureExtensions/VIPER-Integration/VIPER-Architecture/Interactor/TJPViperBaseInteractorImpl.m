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

@interface TJPViperBaseInteractorImpl ()

@property (nonatomic, strong) TJPCacheManager *cacheManager;
@property (nonatomic, strong) TJPViperDefaultErrorHandler *errorHandler;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *uploadProgressMap;
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedTopics;


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
        
        [self setupInteractor];
        _isInitialized = YES;
        
        TJPLOG_INFO(@"[%@] Interactor initialized", NSStringFromClass([self class]));
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
    //提供标准接口 子类需要重写此方法并实现具体的业务逻辑
    TJPLOG_INFO(@"BaseInteractor provide a standard interface - fetchDataForPageWithCompletion.");
    
    // 参数验证
    if (page <= 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"页码必须大于0"}];
        if (failure) failure(error);
        return;
    }
    
    
    
    // 如果是基类被直接调用，抛出标准的TJPNetworkError
    if ([self isMemberOfClass:[TJPViperBaseInteractorImpl class]]) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"子类必须重写此方法"}];
        if (failure) failure(error);
        return;
    }
    
    TJPLOG_INFO(@"[%@] Starting data request for page %ld", NSStringFromClass([self class]), (long)page);
    
    // 执行具体的数据请求（由子类实现）
    [self performDataRequestForPage:page completion:^(NSArray *data, NSInteger totalPage, NSError *error) {
        if (error) {
            TJPLOG_ERROR(@"Data request failed: %@", error.localizedDescription);
            if (failure) failure(error);
        } else {
            TJPLOG_INFO(@"Data request success: %lu items", (unsigned long)data.count);
            
            // 缓存数据
            if ([self shouldCacheDataForPage:page] && data.count > 0) {
                NSString *cacheKey = [self cacheKeyForPage:page];
                [self.cacheManager saveCacheWithData:data forKey:cacheKey expireTime:TJPCacheExpireTimeMedium];
            }
            
            if (success) success(data, totalPage);
        }
    }];
}

#pragma mark - Manage Data
- (void)createData:(NSDictionary *)data completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] Creating data: %@", NSStringFromClass([self class]), data);
    
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
    TJPLOG_INFO(@"[%@] Updating data with ID: %@", NSStringFromClass([self class]), dataId);
    
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
    TJPLOG_INFO(@"[%@] Deleting data with ID: %@", NSStringFromClass([self class]), dataId);
    
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
    TJPLOG_INFO(@"[%@] Searching data with keyword: %@, filters: %@",  NSStringFromClass([self class]), keyword, filters);
    
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

#pragma mark - Manage Cache

- (void)clearCache:(NSString *)cacheKey {
    TJPLOG_INFO(@"[%@] Clearing cache for key: %@", NSStringFromClass([self class]), cacheKey);
    [self.cacheManager removeCacheForKey:cacheKey];
}

- (void)clearAllCache {
    TJPLOG_INFO(@"[%@] Clearing all cache", NSStringFromClass([self class]));
    [self.cacheManager clearAllCache];
}

- (NSUInteger)getCacheSize {
    // 实际项目中可以实现更精确的计算
    return 1024 * 1024 * 3; // 3MB
}

#pragma mark - Manage State

- (void)syncDataToServer:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] Syncing data to server", NSStringFromClass([self class]));
    
    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 发送同步完成信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"sync_to_server", @"status": @"completed"}];
    });
}

- (void)syncDataFromServer:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] Syncing data from server", NSStringFromClass([self class]));
    
    // 基类提供默认实现，子类可重写
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
        
        // 发送同步完成信号
        [self.dataListUpdatedSignal sendNext:@{@"action": @"sync_from_server", @"status": @"completed"}];
    });
}

#pragma mark - Option Method
- (void)subscribeToRealTimeData:(NSString *)topic completion:(void (^)(BOOL, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] Subscribing to real-time data: %@", NSStringFromClass([self class]), topic);
    
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
    TJPLOG_INFO(@"[%@] Unsubscribing from real-time data: %@", NSStringFromClass([self class]), topic);
    [self.subscribedTopics removeObject:topic];
}

- (void)uploadFile:(NSData *)fileData fileName:(NSString *)fileName progress:(void (^)(CGFloat))progress completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    TJPLOG_INFO(@"[%@] Uploading file: %@, size: %lu bytes", NSStringFromClass([self class]), fileName, (unsigned long)fileData.length);
    
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
    // 这是抽象方法，子类必须实现
    NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                         code:TJPViperErrorBusinessLogicFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"子类必须实现performDataRequestForPage:completion:方法"}];
    if (completion) completion(nil, 0, error);
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
    
    // 子类可重写此方法进行清理工作
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
