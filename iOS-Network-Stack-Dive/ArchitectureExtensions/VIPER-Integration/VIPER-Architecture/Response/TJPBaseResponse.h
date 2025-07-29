//
//  TJPBaseResponse.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//  通用API响应基类  支持泛型，可以指定data字段的具体类型

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TJPPaginationInfo;

@interface TJPBaseResponse<__covariant DataType> : NSObject

// 通用响应字段
@property (nonatomic, assign) NSInteger code;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong, nullable) DataType data;
@property (nonatomic, assign) NSInteger totalCount;



// 分页信息（可选）
@property (nonatomic, strong, nullable) TJPPaginationInfo *pagination;

// 原始响应数据（用于调试和扩展）
@property (nonatomic, strong, nullable) NSDictionary *rawResponseDict;

// 便利构造方法
+ (instancetype)responseWithDict:(NSDictionary *)dict;
+ (instancetype)responseWithDict:(NSDictionary *)dict dataClass:(Class)dataClass;

// 子类可重写的解析方法
- (DataType _Nullable)parseDataFromDict:(NSDictionary *)dict;
- (TJPPaginationInfo * _Nullable)parsePaginationFromDict:(NSDictionary *)dict;

// 响应状态判断
- (BOOL)isSuccess;
- (BOOL)hasData;
- (BOOL)hasPagination;

// 调试信息
- (NSString *)debugDescription;


@end

NS_ASSUME_NONNULL_END
