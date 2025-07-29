//
//  TJPPaginationInfo.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPPaginationInfo.h"

@implementation TJPPaginationInfo

+ (instancetype)pageBasedPaginationWithPage:(NSInteger)page pageSize:(NSInteger)pageSize totalCount:(NSInteger)totalCount {
    TJPPaginationInfo *pagination = [[TJPPaginationInfo alloc] init];
    pagination.paginationType = TJPPaginationTypePageBased;
    pagination.currentPage = page;
    pagination.pageSize = pageSize;
    pagination.totalCount = totalCount;
    pagination.totalPages = (totalCount + pageSize - 1) / pageSize; // 向上取整
    pagination.hasMore = page < pagination.totalPages;
    return pagination;
}

+ (instancetype)cursorBasedPaginationWithPageSize:(NSInteger)pageSize nextCursor:(NSString *)nextCursor hasMore:(BOOL)hasMore {
    TJPPaginationInfo *pagination = [[TJPPaginationInfo alloc] init];
    pagination.paginationType = TJPPaginationTypeCursorBased;
    pagination.pageSize = pageSize;
    pagination.nextCursor = nextCursor;
    pagination.hasMore = hasMore;
    return pagination;
}

+ (instancetype)paginationWithDict:(NSDictionary *)dict {
    TJPPaginationInfo *pagination = [[TJPPaginationInfo alloc] init];
    
    // 判断分页类型
    if (dict[@"next_cursor"] || dict[@"nextCursor"]) {
        // 游标分页
        pagination.paginationType = TJPPaginationTypeCursorBased;
        pagination.nextCursor = dict[@"next_cursor"] ?: dict[@"nextCursor"];
        pagination.previousCursor = dict[@"previous_cursor"] ?: dict[@"previousCursor"];
    } else {
        // 页码分页
        pagination.paginationType = TJPPaginationTypePageBased;
        pagination.currentPage = [dict[@"page"] ?: dict[@"current_page"] integerValue];
        pagination.totalCount = [dict[@"total"] ?: dict[@"total_count"] integerValue];
        pagination.totalPages = [dict[@"total_pages"] integerValue];
    }
    
    pagination.pageSize = [dict[@"page_size"] ?: dict[@"pageSize"] integerValue];
    pagination.hasMore = [dict[@"has_more"] ?: dict[@"hasMore"] boolValue];
    
    return pagination;
}

#pragma mark - 工具方法

- (BOOL)canLoadNextPage {
    return self.hasMore;
}

- (BOOL)canLoadPreviousPage {
    if (self.paginationType == TJPPaginationTypePageBased) {
        return self.currentPage > 1;
    } else {
        return self.previousCursor.length > 0;
    }
}

- (NSInteger)getNextPageNumber {
    if (self.paginationType == TJPPaginationTypePageBased) {
        return self.hasMore ? self.currentPage + 1 : self.currentPage;
    }
    return 0; // 游标分页不适用
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"pagination_type"] = @(self.paginationType);
    dict[@"page_size"] = @(self.pageSize);
    dict[@"has_more"] = @(self.hasMore);
    
    if (self.paginationType == TJPPaginationTypePageBased) {
        dict[@"current_page"] = @(self.currentPage);
        dict[@"total_count"] = @(self.totalCount);
        dict[@"total_pages"] = @(self.totalPages);
    } else {
        if (self.nextCursor) dict[@"next_cursor"] = self.nextCursor;
        if (self.previousCursor) dict[@"previous_cursor"] = self.previousCursor;
    }
    
    return [dict copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    TJPPaginationInfo *copy = [[TJPPaginationInfo alloc] init];
    copy.paginationType = self.paginationType;
    copy.pageSize = self.pageSize;
    copy.hasMore = self.hasMore;
    copy.currentPage = self.currentPage;
    copy.totalCount = self.totalCount;
    copy.totalPages = self.totalPages;
    copy.nextCursor = [self.nextCursor copy];
    copy.previousCursor = [self.previousCursor copy];
    return copy;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.paginationType forKey:@"paginationType"];
    [coder encodeInteger:self.pageSize forKey:@"pageSize"];
    [coder encodeBool:self.hasMore forKey:@"hasMore"];
    [coder encodeInteger:self.currentPage forKey:@"currentPage"];
    [coder encodeInteger:self.totalCount forKey:@"totalCount"];
    [coder encodeInteger:self.totalPages forKey:@"totalPages"];
    [coder encodeObject:self.nextCursor forKey:@"nextCursor"];
    [coder encodeObject:self.previousCursor forKey:@"previousCursor"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _paginationType = [coder decodeIntegerForKey:@"paginationType"];
        _pageSize = [coder decodeIntegerForKey:@"pageSize"];
        _hasMore = [coder decodeBoolForKey:@"hasMore"];
        _currentPage = [coder decodeIntegerForKey:@"currentPage"];
        _totalCount = [coder decodeIntegerForKey:@"totalCount"];
        _totalPages = [coder decodeIntegerForKey:@"totalPages"];
        _nextCursor = [coder decodeObjectForKey:@"nextCursor"];
        _previousCursor = [coder decodeObjectForKey:@"previousCursor"];
    }
    return self;
}

@end
