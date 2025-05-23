//
//  TJPViperBaseCellModelProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import "TJPNavigationDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPNavigationModel;

@protocol TJPViperBaseCellModelProtocol <NSObject>

@property (nonatomic, strong) RACCommand<id<TJPViperBaseCellModelProtocol>, NSObject*>* selectedCommand;

// 新增导航元数据方法   使用示例见TJPViperBaseCellModel.m
- (TJPNavigationModel *)navigationModelForCell;

// 返回要跳转的类型 (已废弃)
- (TJPNavigationType)navigationTypeForModel __deprecated_msg("请使用navigationModelForCell方法");

- (NSString *)cellName;
- (CGFloat)cellHeight;

@end

NS_ASSUME_NONNULL_END

