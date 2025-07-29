//
//  TJPFeedResponse.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPBaseResponse.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPPaginationInfo;

@interface TJPFeedResponse : TJPBaseResponse

// Feed特有属性
@property (nonatomic, strong, readonly, nullable) NSArray *feeds;

// Feed特有方法
- (NSInteger)feedCount;
- (BOOL)hasFeedData;
- (NSArray *)getFeedsByType:(NSString *)feedType;
- (NSDictionary *)getFeedStatistics;

+ (instancetype)feedResponseWithDict:(NSDictionary *)dict;


@end

NS_ASSUME_NONNULL_END
