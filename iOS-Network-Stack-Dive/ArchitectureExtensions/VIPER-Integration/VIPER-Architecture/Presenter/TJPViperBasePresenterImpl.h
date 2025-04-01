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


@interface TJPViperBasePresenterImpl : NSObject <TJPViperBasePresenterProtocol>

//presenter->强引用Interactor和router 防止提前释放
@property (nonatomic, strong) id<TJPViperBaseInteractorProtocol> baseInteractor;
@property (nonatomic, strong) id<TJPViperBaseRouterHandlerProtocol> baseRouter;

@end

NS_ASSUME_NONNULL_END
