//
//  TJPViperBaseRouterHandlerProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@class TJPNavigationModel;

@protocol TJPViperBaseRouterHandlerProtocol <NSObject>

@optional
/// 处理跳转逻辑
- (BOOL)handleNavigationLogicWithModel:(TJPNavigationModel *)model context:(UIViewController *)context;

/// 处理跳转方法
- (BOOL)handleRequestWithModel:(TJPNavigationModel *)model context:(UIViewController *)context;



@end

NS_ASSUME_NONNULL_END
