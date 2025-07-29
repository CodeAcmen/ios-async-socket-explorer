//
//  TJPBaseResponse.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseResponse.h"
#import "TJPPaginationInfo.h"

@implementation TJPBaseResponse
+ (instancetype)responseWithDict:(NSDictionary *)dict {
    return [self responseWithDict:dict dataClass:nil];
}

+ (instancetype)responseWithDict:(NSDictionary *)dict dataClass:(Class)dataClass {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    TJPBaseResponse *response = [[self alloc] init];
    response.rawResponseDict = dict;
    
    // 解析基础字段
    response.code = [dict[@"code"] integerValue];
    response.message = dict[@"message"] ?: @"";
    
    // 解析数据字段
    response.data = [response parseDataFromDict:dict];
    
    // 解析分页信息
    response.pagination = [response parsePaginationFromDict:dict];
    
    return response;
}

#pragma mark - 数据解析方法（子类可重写）

- (id)parseDataFromDict:(NSDictionary *)dict {
    // 基类提供默认实现
    id dataValue = dict[@"data"];
    
    if (!dataValue) {
        // 尝试其他可能的字段名
        dataValue = dict[@"result"] ?: dict[@"content"];
    }
    
    return dataValue;
}

- (TJPPaginationInfo *)parsePaginationFromDict:(NSDictionary *)dict {
    // 从多个可能的位置查找分页信息
    NSDictionary *paginationDict = nil;
    
    // 1. 尝试从data字段中获取
    if ([dict[@"data"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = dict[@"data"];
        paginationDict = dataDict[@"pagination"] ?: dataDict[@"page_info"] ?: dataDict[@"paging"];
    }
    
    // 2. 尝试从根级别获取
    if (!paginationDict) {
        paginationDict = dict[@"pagination"] ?: dict[@"page_info"] ?: dict[@"paging"];
    }
    
    if (paginationDict && [paginationDict isKindOfClass:[NSDictionary class]]) {
        return [TJPPaginationInfo paginationWithDict:paginationDict];
    }
    
    return nil;
}

#pragma mark - 状态判断方法

- (BOOL)isSuccess {
    return self.code == 200 || self.code == 0; // 支持不同的成功码规范
}

- (BOOL)hasData {
    return self.data != nil;
}

- (BOOL)hasPagination {
    return self.pagination != nil;
}

#pragma mark - 调试信息

- (NSString *)debugDescription {
    NSMutableString *debug = [NSMutableString string];
    [debug appendFormat:@"<%@: %p>\n", NSStringFromClass([self class]), self];
    [debug appendFormat:@"  code: %ld\n", (long)self.code];
    [debug appendFormat:@"  message: %@\n", self.message];
    [debug appendFormat:@"  hasData: %@\n", @(self.hasData)];
    [debug appendFormat:@"  hasPagination: %@\n", @(self.hasPagination)];
    
    if (self.pagination) {
        [debug appendFormat:@"  pagination: %@\n", self.pagination.debugDescription];
    }
    
    return [debug copy];
}

@end
