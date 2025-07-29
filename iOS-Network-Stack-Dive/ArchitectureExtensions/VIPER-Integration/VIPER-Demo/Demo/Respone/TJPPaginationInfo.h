//
//  TJPPaginationInfo.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TJPPaginationType) {
    TJPPaginationTypePageBased = 0,  // 基于页码的分页
    TJPPaginationTypeCursorBased = 1 // 基于游标的分页
};

@interface TJPPaginationInfo : NSObject

// 通用属性
@property (nonatomic, assign) TJPPaginationType paginationType;
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, assign) BOOL hasMore;

// 基于页码的分页属性 (Page-based)
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger totalCount;
@property (nonatomic, assign) NSInteger totalPages;

// 基于游标的分页属性 (Cursor-based)
@property (nonatomic, strong, nullable) NSString *nextCursor;
@property (nonatomic, strong, nullable) NSString *previousCursor;



+ (instancetype)pageBasedPaginationWithPage:(NSInteger)page pageSize:(NSInteger)pageSize totalCount:(NSInteger)totalCount;

+ (instancetype)cursorBasedPaginationWithPageSize:(NSInteger)pageSize nextCursor:(nullable NSString *)nextCursor hasMore:(BOOL)hasMore;

+ (instancetype)paginationWithDict:(NSDictionary *)dict;

// 工具方法
- (BOOL)canLoadNextPage;
- (BOOL)canLoadPreviousPage;
// 仅适用于页码分页
- (NSInteger)getNextPageNumber;
- (NSDictionary *)toDictionary;


@end

NS_ASSUME_NONNULL_END
