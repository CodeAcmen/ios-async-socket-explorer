//
//  TJPViperModuleAssembly.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Typhoon/Typhoon.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperModuleProvider;

@interface TJPViperModuleAssembly : TyphoonAssembly

@property (nonatomic, strong, readonly) TyphoonAssembly<TJPViperModuleProvider> *tjpViperModuleProvider;


@end

NS_ASSUME_NONNULL_END
