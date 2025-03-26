//
//  TJPLogModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//  日志内容模型

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPLogModel : NSObject

/// 类名
@property (nonatomic, copy) NSString *clsName;
/// 方法名
@property (nonatomic, copy) NSString *methodName;
/// 参数
@property (nonatomic, strong) NSArray *arguments;
/// 执行时间
@property (nonatomic, assign) NSTimeInterval executeTime;
/// 异常
@property (nonatomic, strong) NSException *exception;

@end

NS_ASSUME_NONNULL_END
