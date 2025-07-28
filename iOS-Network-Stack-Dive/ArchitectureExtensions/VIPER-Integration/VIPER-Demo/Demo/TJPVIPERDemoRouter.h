//
//  TJPVIPERDemoRouter.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/28.
//

#import "TJPViperBaseRouterImpl.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPVIPERDemoRouter : TJPViperBaseRouterImpl

@property (nonatomic, strong) id<TJPViperModuleProvider> viperModuleProvider;


@end

NS_ASSUME_NONNULL_END
