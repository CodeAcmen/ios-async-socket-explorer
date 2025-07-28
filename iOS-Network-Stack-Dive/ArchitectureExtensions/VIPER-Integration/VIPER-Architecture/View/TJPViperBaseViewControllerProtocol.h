//
//  TJPViperBaseViewControllerProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseViewControllerProtocol <NSObject>

@required
- (UIViewController *)currentViewController;

@optional
- (void)showError:(NSString *)error;


@end

NS_ASSUME_NONNULL_END
