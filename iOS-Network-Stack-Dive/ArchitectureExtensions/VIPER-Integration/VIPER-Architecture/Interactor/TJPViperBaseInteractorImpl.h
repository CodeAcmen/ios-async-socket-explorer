//
//  TJPViperBaseInteractorImpl.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>
#import "TJPViperBaseInteractorProtocol.h"
#import "TJPViperErrorDefine.h"
#import "TJPCacheManager.h"
#import "TJPViperDefaultErrorHandler.h"


NS_ASSUME_NONNULL_BEGIN

@interface TJPViperBaseInteractorImpl : NSObject <TJPViperBaseInteractorProtocol>

// 基础控件
@property (nonatomic, strong, readonly) TJPCacheManager *cacheManager;
@property (nonatomic, strong, readonly) TJPViperDefaultErrorHandler *errorHandler;

// 网络配置
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (nonatomic, assign) NSInteger maxRetryCount;

// 状态管理
@property (nonatomic, assign, readonly) BOOL isInitialized;


// 快速定义错误
- (NSError *)createErrorWithCode:(TJPViperError)errorCode description:(NSString *)description;

// 子类需要实现的抽象方法
- (void)performDataRequestForPage:(NSInteger)page
                       completion:(void (^)(NSArray * _Nullable data, NSInteger totalPage, NSError * _Nullable error))completion;

// 子类可重写的方法
- (NSString *)baseURLString;
- (NSDictionary *)commonParameters;
- (NSDictionary *)parametersForPage:(NSInteger)page;
- (NSArray *)processRawResponseData:(id)rawData;
- (NSError * _Nullable)validateResponseData:(id)rawData;

// 工具方法
- (NSString *)cacheKeyForPage:(NSInteger)page;
- (BOOL)shouldCacheDataForPage:(NSInteger)page;

// 子类可重写的扩展方法
- (void)setupInteractor;
- (void)teardownInteractor;

@end

NS_ASSUME_NONNULL_END
