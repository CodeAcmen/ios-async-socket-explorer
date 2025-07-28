//
//  TJPViperModuleProvider.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperModuleProvider <NSObject>



/// VIPER示例VC
- (UIViewController *)viperDemoViewController;


- (UIViewController *)viperDemoDetailViewController;

@end

NS_ASSUME_NONNULL_END
