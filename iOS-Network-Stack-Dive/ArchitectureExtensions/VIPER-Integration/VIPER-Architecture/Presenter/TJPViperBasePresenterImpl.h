//
//  TJPViperBasePresenterImpl.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>
#import "TJPViperBasePresenterProtocol.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseInteractorProtocol, TJPViperBaseRouterHandlerProtocol;
@class TJPViperDefaultErrorHandler;

@interface TJPViperBasePresenterImpl : NSObject <TJPViperBasePresenterProtocol>

// 核心组件
//presenter->强引用Interactor和router 防止提前释放
@property (nonatomic, strong) id<TJPViperBaseInteractorProtocol> baseInteractor;
@property (nonatomic, strong) id<TJPViperBaseRouterHandlerProtocol> baseRouter;

// 错误处理
@property (nonatomic, strong, readonly) TJPViperDefaultErrorHandler *errorHandler;

// 状态管理
@property (nonatomic, assign, readonly) BOOL isProcessingRequest;
@property (nonatomic, strong, readonly) NSError *lastError;
@property (nonatomic, strong, readonly) NSMutableDictionary *businessStateStorage;


// 弱引用的ViewController（避免循环引用）
@property (nonatomic, weak) UIViewController *currentViewController;



// 子类可重写的业务逻辑方法
- (void)preprocessRequestForPage:(NSInteger)page;
- (void)postprocessResponseData:(NSArray *)data;
- (BOOL)validateResponseData:(NSArray *)data;
- (void)handleBusinessError:(NSError *)error;

// 子类可重写的生命周期扩展方法
- (void)setupPresenter;
- (void)teardownPresenter;

@end

NS_ASSUME_NONNULL_END
