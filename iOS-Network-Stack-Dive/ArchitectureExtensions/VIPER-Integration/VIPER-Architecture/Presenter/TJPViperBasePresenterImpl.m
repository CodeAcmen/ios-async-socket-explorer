//
//  TJPViperBasePresenterImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBasePresenterImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPViperDefaultErrorHandler.h"
#import "TJPViperBaseInteractorProtocol.h"
#import "TJPViperBaseRouterHandlerProtocol.h"
#import "TJPBaseCellModelProtocol.h"


@interface TJPViperBasePresenterImpl ()

@property (nonatomic, assign) BOOL isProcessingRequest;
@property (nonatomic, strong) NSError *lastError;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *activeRequests;
@property (nonatomic, strong) TJPViperDefaultErrorHandler *errorHandler;
@property (nonatomic, strong) NSMutableDictionary *businessStateStorage;
@property (nonatomic, assign) BOOL isInitialized;


@end

@implementation TJPViperBasePresenterImpl
@synthesize viewUpdatedDataSignal = _viewUpdatedDataSignal;


#pragma mark - Life Cycle
- (instancetype)init {
    self = [super init];
    if (self) {
        _activeRequests = [NSMutableSet set];
        _isProcessingRequest = NO;
        _errorHandler = [TJPViperDefaultErrorHandler sharedHandler];
        _businessStateStorage = [NSMutableDictionary dictionary];
        _isInitialized = NO;
        
        [self setupPresenter];
    }
    return self;
}

- (void)dealloc {
    TJPLogDealloc();
}



#pragma mark - Signal bind
- (RACSubject<NSDictionary *> *)viewUpdatedDataSignal {
    if (!_viewUpdatedDataSignal) {
        _viewUpdatedDataSignal = [RACSubject subject];
    }
    return _viewUpdatedDataSignal;
}


- (void)bindInteractorToPageSubjectWithView:(UIViewController *)vc {
    if (!vc || !self.baseInteractor) {
        TJPLOG_ERROR(@"Cannot bind signals: vc=%@, interactor=%@", vc, self.baseInteractor);
        return;
    }
    
    // 保存ViewController的弱引用
    self.currentViewController = vc;
    
    //此处vc使用weak修饰 防止循环引用出现
    __weak typeof(UIViewController *)weakVC = vc;
    @weakify(self)
    [[[[[self.baseInteractor.navigateToPageSubject takeUntil:self.rac_willDeallocSignal] deliverOnMainThread] map:^id _Nullable(id<TJPBaseCellModelProtocol> model) {
        // 安全类型转换
        if (![model conformsToProtocol:@protocol(TJPBaseCellModelProtocol)]) {
            [NSException raise:NSInvalidArgumentException format:@"Invalid model type"];
        }
        return [model navigationModelForCell];
    }]
      filter:^BOOL(TJPNavigationModel *model) {
        return model != nil;
    }]
     subscribeNext:^(TJPNavigationModel * _Nullable model) {
        @strongify(self)
        if (!weakVC) {
            TJPLOG_ERROR(@"ViewController has been deallocated during navigation");
            return;
        }
        
        //信号订阅成功 交给路由管理
        TJPLOG_INFO(@"Received model for page: %@", model);
        
        BOOL navigationSuccess = [self.baseRouter handleNavigationLogicWithModel:model context:weakVC];
        
        if (!navigationSuccess) {
            TJPLOG_ERROR(@"Navigation failed for model: %@", model);
            
            // 使用错误处理器处理导航失败
            NSError *navError = [NSError errorWithDomain:TJPViperErrorDomain
                                                    code:TJPViperErrorNavigationFailed
                                                userInfo:@{NSLocalizedDescriptionKey: @"页面跳转失败"}];
            [self.errorHandler handleError:navError inContext:weakVC completion:^(BOOL shouldRetry) {
                
            }];
            
        }
    }];
}

- (void)bindInteractorDataUpdateSubject {
    if (!self.baseInteractor) {
        TJPLOG_ERROR(@"Cannot bind data update signals: interactor is nil");
        return;
    }
    
    @weakify(self)
    [[self.baseInteractor.dataListUpdatedSignal takeUntil:self.rac_willDeallocSignal] subscribeNext:^(NSDictionary *  _Nullable x) {
        @strongify(self)
        TJPLOG_INFO(@"[%@] Received data update signal from Interactor", NSStringFromClass([self class]));
        [self.viewUpdatedDataSignal sendNext:x];
    }];
}


#pragma mark - Load Data
- (void)fetchInteractorDataForPage:(NSInteger)page success:(void (^)(NSArray * _Nonnull, NSInteger))success failure:(void (^)(NSError * _Nonnull))failure {
    // 参数验证
    if (page <= 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorDataInvalid
                                         userInfo:@{NSLocalizedDescriptionKey: @"页码必须大于0"}];
        if (failure) failure(error);
        return;
    }
    
    // 检查是否有相同页码的请求正在进行
    NSNumber *pageKey = @(page);
    if ([self.activeRequests containsObject:pageKey]) {
        TJPLOG_INFO(@"Request for page %ld already in progress", (long)page);
        return;
    }
    
    // 预处理请求
    [self preprocessRequestForPage:page];
    
    // 标记请求开始
    [self.activeRequests addObject:pageKey];
    self.isProcessingRequest = YES;
    
    @weakify(self)
    [self.baseInteractor fetchDataForPageWithCompletion:page
                                                success:^(NSArray *data, NSInteger totalPage) {
        @strongify(self)
        
        // 清理请求状态
        [self.activeRequests removeObject:pageKey];
        self.isProcessingRequest = self.activeRequests.count > 0;
        self.lastError = nil;
        
        // 验证响应数据
        if (![self validateResponseData:data]) {
            NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                                 code:TJPViperErrorDataInvalid
                                             userInfo:@{NSLocalizedDescriptionKey: @"服务器返回数据格式错误"}];
            [self handleBusinessError:error];
            if (failure) failure(error);
            return;
        }
        
        // 后处理响应数据
        [self postprocessResponseData:data];
        
        TJPLOG_INFO(@"✅ [%@] Data fetch success for page %ld",
                    NSStringFromClass([self class]), (long)page);
        
        if (success) success(data, totalPage);
        
    } failure:^(NSError *error) {
        @strongify(self)
        
        // 清理请求状态
        [self.activeRequests removeObject:pageKey];
        self.isProcessingRequest = self.activeRequests.count > 0;
        self.lastError = error;
        
        // 处理业务错误
        [self handleBusinessError:error];
        
        TJPLOG_ERROR(@"❌ [%@] Data fetch failed for page %ld: %@",
                     NSStringFromClass([self class]), (long)page, error.localizedDescription);
        
        if (failure) failure(error);
    }];
}

#pragma mark - Manage Status

- (void)presenterDidInitialize {
    if (self.isInitialized) {
        TJPLOG_WARN(@"Presenter already initialized");
        return;
    }
    
    self.isInitialized = YES;
    TJPLOG_INFO(@"[%@] Presenter initialized", NSStringFromClass([self class]));
    
    // 初始化业务状态
    [self resetBusinessState];
}

- (void)viewWillAppear {
    TJPLOG_INFO(@"[%@] viewWillAppear", NSStringFromClass([self class]));
    
    // 子类可重写此方法进行特定处理
}

- (void)viewDidAppear {
    TJPLOG_INFO(@"[%@] viewDidAppear", NSStringFromClass([self class]));
    
    // 子类可重写此方法进行特定处理
}

- (void)viewWillDisappear {
    TJPLOG_INFO(@"[%@] viewWillDisappear", NSStringFromClass([self class]));
    
    // 子类可重写此方法进行特定处理
}

- (void)viewDidDisappear {
    TJPLOG_INFO(@"[%@] viewDidDisappear", NSStringFromClass([self class]));
    
    // 子类可重写此方法进行特定处理
}

#pragma mark - Manage State

- (NSDictionary *)currentBusinessState {
    NSMutableDictionary *state = [self.businessStateStorage mutableCopy];
    
    // 添加基础状态信息
    state[@"isProcessingRequest"] = @(self.isProcessingRequest);
    state[@"hasError"] = @(self.lastError != nil);
    state[@"isInitialized"] = @(self.isInitialized);
    state[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    if (self.lastError) {
        state[@"lastError"] = @{
            @"domain": self.lastError.domain,
            @"code": @(self.lastError.code),
            @"message": self.lastError.localizedDescription
        };
    }
    
    return [state copy];
}

- (void)resetBusinessState {
    [self.businessStateStorage removeAllObjects];
    self.lastError = nil;
    
    // 设置默认状态
    self.businessStateStorage[@"initialized"] = @YES;
    
    TJPLOG_INFO(@"[%@] Business state reset", NSStringFromClass([self class]));
}

#pragma mark - User Interactor

- (void)handleUserInteraction:(NSString *)event withData:(nullable id)data {
    TJPLOG_INFO(@"[%@] Handling user interaction: %@ with data: %@",
                NSStringFromClass([self class]), event, data);
    
    // 基类提供默认实现，子类可重写
    // 这里可以添加通用的用户交互处理逻辑
}

- (NSError * _Nullable)validateUserInput:(NSDictionary *)input {
    // 基础验证
    if (!input || ![input isKindOfClass:[NSDictionary class]]) {
        return [NSError errorWithDomain:TJPViperErrorDomain
                                   code:TJPViperErrorDataInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"输入数据格式错误"}];
    }
    
    // 子类可重写此方法进行特定验证
    return nil; // 验证通过
}

- (BOOL)handleDeepLink:(NSURL *)url parameters:(NSDictionary *)parameters {
    TJPLOG_INFO(@"[%@] Handling deep link: %@ with parameters: %@",
                NSStringFromClass([self class]), url, parameters);
    
    // 基类提供默认实现，子类可重写
    return NO; // 默认不处理
}

- (void)handlePushNotification:(NSDictionary *)notification {
    TJPLOG_INFO(@"[%@] Handling push notification: %@",
                NSStringFromClass([self class]), notification);
    
    // 基类提供默认实现，子类可重写
}

- (void)preloadData {
    TJPLOG_INFO(@"[%@] Preloading data", NSStringFromClass([self class]));
    
    // 基类提供默认实现，子类可重写
}

- (void)cleanup {
    TJPLOG_INFO(@"[%@] Cleaning up resources", NSStringFromClass([self class]));
    
    // 清理业务状态
    [self.businessStateStorage removeAllObjects];
    
    // 清理请求状态
    [self.activeRequests removeAllObjects];
    self.isProcessingRequest = NO;
    self.lastError = nil;
    
    // 子类可重写此方法进行特定清理
}

#pragma mark - 子类可重写的业务逻辑方法

- (void)preprocessRequestForPage:(NSInteger)page {
    TJPLOG_INFO(@"[%@] Preprocessing request for page %ld",
                NSStringFromClass([self class]), (long)page);
    // 子类可重写
}

- (void)postprocessResponseData:(NSArray *)data {
    TJPLOG_INFO(@"[%@] Postprocessing response data with %lu items",
                NSStringFromClass([self class]), (unsigned long)data.count);
    // 子类可重写
}

- (BOOL)validateResponseData:(NSArray *)data {
    if (!data || ![data isKindOfClass:[NSArray class]]) {
        return NO;
    }
    return YES; // 子类可重写进行更详细的验证
}

- (void)handleBusinessError:(NSError *)error {
    TJPLOG_ERROR(@"[%@] Business error occurred: %@",
                 NSStringFromClass([self class]), error.localizedDescription);
    // 子类可重写
}

#pragma mark - 子类可重写的扩展方法

- (void)setupPresenter {
    // 子类可重写此方法进行初始化设置
}

- (void)teardownPresenter {
    // 子类可重写此方法进行清理工作
}



@end


