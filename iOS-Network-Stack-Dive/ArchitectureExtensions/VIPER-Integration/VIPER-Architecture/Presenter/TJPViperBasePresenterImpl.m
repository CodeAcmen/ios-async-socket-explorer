//
//  TJPViperBasePresenterImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBasePresenterImpl.h"
#import "TJPViperBaseViewControllerProtocol.h"
#import "TJPNetworkDefine.h"
#import "TJPViperDefaultErrorHandler.h"
#import "TJPViperBaseInteractorProtocol.h"
#import "TJPViperBaseRouterHandlerProtocol.h"
#import "TJPBaseCellModelProtocol.h"
#import "TJPNavigationModel.h"
#import "TJPPaginationInfo.h"


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
    [self teardownPresenter];
}



#pragma mark - Signal bind
- (RACSubject<NSDictionary *> *)viewUpdatedDataSignal {
    if (!_viewUpdatedDataSignal) {
        _viewUpdatedDataSignal = [RACSubject subject];
    }
    return _viewUpdatedDataSignal;
}


- (void)bindInteractorToPageSubjectWithContextProvider:(id<TJPViperBaseViewControllerProtocol>)contextProvider {
    self.contextProvider = contextProvider;

    if (!contextProvider || !self.baseInteractor) {
        TJPLOG_ERROR(@"无法绑定信号: contextProvider=%@, interactor=%@", contextProvider, self.baseInteractor);
        return;
    }
    
    @weakify(self)
    [[[self.baseInteractor.navigateToPageSubject takeUntil:self.rac_willDeallocSignal] deliverOnMainThread] subscribeNext:^(id<TJPBaseCellModelProtocol> cellModel) {
        @strongify(self)
        if (!self.contextProvider) {
            TJPLOG_ERROR(@"contextProvider在跳转期间已被释放");
            return;
        }
        TJPLOG_INFO(@"接收到Cell模型信号: %@", NSStringFromClass([cellModel class]));
        
        // ===== 从CellModel构建TJPNavigationModel 模板方法：基类定义流程，子类实现具体逻辑 =====
        TJPNavigationModel *navigationModel = [self buildNavigationModelFromCellModel:cellModel];
                
        if (!navigationModel) {
            TJPLOG_ERROR(@"无法从CellModel构建NavigationModel: %@", NSStringFromClass([cellModel class]));
            return;
        }
        
        UIViewController *fromVC = [self.contextProvider currentViewController];
        if (!fromVC) {
            TJPLOG_ERROR(@"无法获取当前上下文 VC，跳转终止");
            return;
        }
        
        // 信号订阅成功 交给路由管理
        BOOL navigationSuccess = [self.baseRouter navigateToRouteWithNavigationModel:navigationModel fromContext:fromVC animated:YES];
        
        if (!navigationSuccess) {
            TJPLOG_ERROR(@"模型导航失败: %@", cellModel);

            // 使用错误处理器处理导航失败
            NSError *navError = [NSError errorWithDomain:TJPViperErrorDomain
                                                    code:TJPViperErrorNavigationFailed
                                                userInfo:@{NSLocalizedDescriptionKey: @"页面跳转失败"}];
            [self.errorHandler handleError:navError inContext:fromVC completion:^(BOOL shouldRetry) {
                
            }];
            
        }
    }];
}


- (TJPNavigationModel *)buildNavigationModelFromCellModel:(id<TJPBaseCellModelProtocol>)cellModel {
    // 基类提供默认实现，但建议子类重写
    TJPLOG_WARN(@"[%@] 子类应该重写 buildNavigationModelFromCellModel: 方法", NSStringFromClass([self class]));
    
    // 基类提供最基础的默认实现
    return [self defaultNavigationModelFromCellModel:cellModel];
}

- (void)bindInteractorDataUpdateSubject {
    if (!self.baseInteractor) {
        TJPLOG_ERROR(@"无法绑定数据更新信号: interactor 为空");
        return;
    }
    
    @weakify(self)
    [[self.baseInteractor.dataListUpdatedSignal takeUntil:self.rac_willDeallocSignal] subscribeNext:^(NSDictionary *  _Nullable x) {
        @strongify(self)
        TJPLOG_INFO(@"[%@] 接收到来自Interactor的数据更新信号", NSStringFromClass([self class]));
        [self.viewUpdatedDataSignal sendNext:x];
    }];
}


#pragma mark - Load Data
- (void)fetchInteractorDataForPage:(NSInteger)page success:(void (^)(NSArray * _Nonnull, NSInteger))success failure:(void (^)(NSError * _Nonnull))failure {
    // 向后兼容的方法
    [self fetchInteractorDataForPageWithPagination:page success:^(NSArray *data, TJPPaginationInfo *pagination) {
        if (success) {
            NSInteger totalPage = pagination && pagination.paginationType == TJPPaginationTypePageBased ? pagination.totalPages : 0;
            success(data, totalPage);
        }
    } failure:failure];
}

- (void)fetchInteractorDataForPageWithPagination:(NSInteger)page success:(void (^)(NSArray * _Nonnull, TJPPaginationInfo * _Nullable))success failure:(void (^)(NSError * _Nonnull))failure {
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
        TJPLOG_INFO(@"第 %ld 页的请求已经在进行中", (long)page);
        return;
    }
    
    // 预处理请求
    [self preprocessRequestForPage:page];
    
    // 标记请求开始
    [self.activeRequests addObject:pageKey];
    self.isProcessingRequest = YES;
    
    @weakify(self)
    // 优先使用新的分页方法
    if ([self.baseInteractor respondsToSelector:@selector(fetchDataForPageWithPagination:success:failure:)]) {
        [self.baseInteractor fetchDataForPageWithPagination:page success:^(NSArray *data, TJPPaginationInfo *pagination) {
            @strongify(self)
            [self handleDataLoadSuccess:data pagination:pagination pageKey:pageKey success:success];
        } failure:^(NSError *error) {
            @strongify(self)
            [self handleDataLoadFailure:error pageKey:pageKey failure:failure];
        }];
    } else {
        // 回退到旧方法
        [self.baseInteractor fetchDataForPageWithCompletion:page  success:^(NSArray *data, NSInteger totalPage) {
            @strongify(self)
            // 从旧方法构造分页信息
            TJPPaginationInfo *pagination = nil;
            if (totalPage > 0) {
                pagination = [TJPPaginationInfo pageBasedPaginationWithPage:page pageSize:data.count totalCount:totalPage * data.count];
            }
            [self handleDataLoadSuccess:data pagination:pagination pageKey:pageKey success:success];
        } failure:^(NSError *error) {
            @strongify(self)
            [self handleDataLoadFailure:error pageKey:pageKey failure:failure];
        }];
    }
}
#pragma mark - Data Load Response Handling - 数据加载响应处理

- (void)handleDataLoadSuccess:(NSArray *)data pagination:(TJPPaginationInfo *)pagination pageKey:(NSNumber *)pageKey success:(void (^)(NSArray *, TJPPaginationInfo *))success {
    
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
        return;
    }
    
    // 后处理响应数据
    [self postprocessResponseData:data];
    
    TJPLOG_INFO(@"[%@] 第 %@ 页数据请求成功，分页信息: %@",
                NSStringFromClass([self class]), pageKey, pagination.debugDescription);
    
    if (success) success(data, pagination);
}

- (void)handleDataLoadFailure:(NSError *)error pageKey:(NSNumber *)pageKey failure:(void (^)(NSError *))failure {
    
    // 清理请求状态
    [self.activeRequests removeObject:pageKey];
    self.isProcessingRequest = self.activeRequests.count > 0;
    self.lastError = error;
    
    // 处理业务错误
    [self handleBusinessError:error];
    
    TJPLOG_ERROR(@"[%@] 第 %@ 页数据请求失败: %@",
                 NSStringFromClass([self class]), pageKey, error.localizedDescription);
    
    if (failure) failure(error);
}

#pragma mark - Manage Status

- (void)presenterDidInitialize {
    if (self.isInitialized) {
        TJPLOG_WARN(@"Presenter 已经初始化过");
        return;
    }
    
    self.isInitialized = YES;
    TJPLOG_INFO(@"[%@] Presenter 初始化完成", NSStringFromClass([self class]));

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
    
    TJPLOG_INFO(@"[%@] 业务状态已重置", NSStringFromClass([self class]));
}

#pragma mark - User Interactor

- (void)handleUserInteraction:(NSString *)event withData:(nullable id)data {
    TJPLOG_INFO(@"[%@] 处理用户交互事件: %@，数据: %@", NSStringFromClass([self class]), event, data);

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
    TJPLOG_INFO(@"[%@] 处理深度链接: %@，参数: %@", NSStringFromClass([self class]), url, parameters);

    // 基类提供默认实现，子类可重写
    return NO; // 默认不处理
}

- (void)handlePushNotification:(NSDictionary *)notification {
    TJPLOG_INFO(@"[%@] 处理推送通知: %@", NSStringFromClass([self class]), notification);

    // 基类提供默认实现，子类可重写
}

- (void)preloadData {
    TJPLOG_INFO(@"[%@] 预加载数据", NSStringFromClass([self class]));

    // 基类提供默认实现，子类可重写
}

- (void)cleanup {
    TJPLOG_INFO(@"[%@] 清理资源", NSStringFromClass([self class]));

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
    TJPLOG_INFO(@"[%@] 正在预处理第 %ld 页的请求", NSStringFromClass([self class]), (long)page);
    // 子类可重写
}

- (void)postprocessResponseData:(NSArray *)data {
    TJPLOG_INFO(@"[%@] 正在后处理 %lu 条响应数据", NSStringFromClass([self class]), (unsigned long)data.count);
    // 子类可重写
}

- (BOOL)validateResponseData:(NSArray *)data {
    if (!data || ![data isKindOfClass:[NSArray class]]) {
        return NO;
    }
    return YES; // 子类可重写进行更详细的验证
}

- (void)handleBusinessError:(NSError *)error {
    TJPLOG_ERROR(@"[%@] 发生业务错误: %@", NSStringFromClass([self class]), error.localizedDescription);
    // 子类可重写
}

#pragma mark - 子类可重写的扩展方法

- (void)setupPresenter {
    // 子类可重写此方法进行初始化设置
}

- (void)teardownPresenter {
    // 子类可重写此方法进行清理工作
}


#pragma mark - Private Method
- (TJPNavigationModel *)defaultNavigationModelFromCellModel:(id<TJPBaseCellModelProtocol>)cellModel {
    if (!cellModel) {
        return nil;
    }
    
    // 基于类名约定生成routeId
    NSString *className = NSStringFromClass([cellModel class]);
    NSString *routeId = nil;
    
    if ([className hasSuffix:@"CellModel"]) {
        NSString *prefix = [className substringToIndex:className.length - 9]; // 去掉"CellModel"
        if ([prefix hasPrefix:@"TJP"]) {
            prefix = [prefix substringFromIndex:3]; // 去掉"TJP"前缀
        }
        routeId = [prefix lowercaseString];
    } else {
        routeId = @"unknown";
    }
    
    // 构建基础参数
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"cellType"] = className;
    parameters[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    // 尝试提取一些通用属性
    if ([cellModel respondsToSelector:@selector(title)]) {
        id title = [(NSObject *)cellModel valueForKey:@"title"];
        if (title) parameters[@"title"] = title;
    }
    
    TJPNavigationModel *model = [TJPNavigationModel modelWithRouteId:routeId parameters:[parameters copy] routeType:TJPNavigationRouteTypeViewPush];
    model.animated = YES;
    
    TJPLOG_INFO(@"[%@] 使用默认实现构建NavigationModel: %@ -> %@", NSStringFromClass([self class]), className, routeId);
    
    return model;
}


@end


