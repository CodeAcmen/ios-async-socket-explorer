//
//  TJPFeedResponse.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPFeedResponse.h"
#import "TJPPaginationInfo.h"

@implementation TJPFeedResponse

- (NSArray *)feeds {
    // 向后兼容：feeds属性实际就是data属性
    return self.data;
}

+ (instancetype)feedResponseWithDict:(NSDictionary *)dict {
    return [self responseWithDict:dict dataClass:[NSArray class]];
}

- (NSArray *)parseDataFromDict:(NSDictionary *)dict {
    // Feed业务的特定解析逻辑
    id dataValue = dict[@"data"];
    
    if ([dataValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = (NSDictionary *)dataValue;
        
        // 尝试多个可能的字段名
        NSArray *feedsArray = dataDict[@"feeds"] ?: dataDict[@"list"] ?: dataDict[@"items"];
        
        if ([feedsArray isKindOfClass:[NSArray class]]) {
            return feedsArray;
        }
    } else if ([dataValue isKindOfClass:[NSArray class]]) {
        // 数据直接是数组格式
        return (NSArray *)dataValue;
    }
    
    // 容错处理：如果解析失败，返回空数组而不是nil
    NSLog(@"Feed数据解析失败，返回空数组");
    return @[];
}

- (TJPPaginationInfo *)parsePaginationFromDict:(NSDictionary *)dict {
    // 调用父类方法
    TJPPaginationInfo *pagination = [super parsePaginationFromDict:dict];
    
    // Feed业务的特殊处理
    if (!pagination) {
        // 如果没有找到分页信息，尝试从feeds数据推断
        NSArray *feeds = self.data;
        if (feeds && feeds.count > 0) {
            // 创建一个默认的分页信息
            NSLog(@"未找到分页信息，创建默认分页信息");
            pagination = [TJPPaginationInfo pageBasedPaginationWithPage:1 pageSize:feeds.count totalCount:feeds.count];
        }
    }
    
    return pagination;
}

- (NSInteger)feedCount {
    return self.feeds ? self.feeds.count : 0;
}

- (BOOL)hasFeedData {
    return self.feedCount > 0;
}

- (NSArray *)getFeedsByType:(NSString *)feedType {
    if (!feedType || !self.feeds) {
        return @[];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", feedType];
    return [self.feeds filteredArrayUsingPredicate:predicate];
}

- (NSDictionary *)getFeedStatistics {
    if (!self.hasFeedData) {
        return @{};
    }
    
    NSMutableDictionary *statistics = [NSMutableDictionary dictionary];
    NSMutableDictionary *typeCounts = [NSMutableDictionary dictionary];
    
    // 统计各种类型的数量
    for (NSDictionary *feed in self.feeds) {
        if ([feed isKindOfClass:[NSDictionary class]]) {
            NSString *type = feed[@"type"] ?: @"unknown";
            NSNumber *count = typeCounts[type] ?: @0;
            typeCounts[type] = @(count.integerValue + 1);
        }
    }
    
    statistics[@"total_count"] = @(self.feedCount);
    statistics[@"type_counts"] = [typeCounts copy];
    statistics[@"types"] = [typeCounts allKeys];
    
    return [statistics copy];
}

@end
