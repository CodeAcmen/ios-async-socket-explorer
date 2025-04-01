//
//  HomeViewController.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperModuleProvider;

@interface HomeViewController : UIViewController

@property (nonatomic, strong) id<TJPViperModuleProvider> tjpViperModuleProvider;


@end

NS_ASSUME_NONNULL_END
