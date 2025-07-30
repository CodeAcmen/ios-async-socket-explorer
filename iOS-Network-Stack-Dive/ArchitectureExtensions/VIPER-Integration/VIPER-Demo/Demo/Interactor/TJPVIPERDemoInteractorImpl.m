//
//  TJPVIPERDemoInteractorImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import "TJPVIPERDemoInteractorImpl.h"
#import <YYModel/YYModel.h>
#import "TJPNetworkDefine.h"
#import "TJPCacheManager.h"
#import "TJPBaseSectionModel.h"
#import "TJPFeedResponse.h"
#import "TJPPaginationInfo.h"

#import "TJPNewsCellModel.h"
#import "TJPImageCellModel.h"
#import "TJPVideoCellModel.h"
#import "TJPUserDynamicCellModel.h"
#import "TJPProductCellModel.h"
#import "TJPAdCellModel.h"



@interface TJPVIPERDemoInteractorImpl ()

@property (nonatomic, assign) NSInteger totalCount;


//@property (nonatomic, strong) RACCommand <TJPVIPERDemoCellModel *, NSObject *>*selectedDemoDetilCommand;


@property (nonatomic, strong) RACCommand *selectedNewsCommand;
@property (nonatomic, strong) RACCommand *selectedImageCommand;
@property (nonatomic, strong) RACCommand *selectedVideoCommand;
@property (nonatomic, strong) RACCommand *selectedUserDynamicCommand;
@property (nonatomic, strong) RACCommand *selectedProductCommand;
@property (nonatomic, strong) RACCommand *selectedAdCommand;

@end

@implementation TJPVIPERDemoInteractorImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _totalCount = 0;
    }
    return self;
}

- (void)performDataRequestForPage:(NSInteger)page
                   withPagination:(void (^)(NSArray * _Nullable, TJPPaginationInfo * _Nullable, NSError * _Nullable))completion {
    
    NSString *api = @"https://www.tjp.example.demo.api";
    
    TJPLOG_INFO(@"开始请求第 %ld 页数据，API: %@", page, api);
    
    //网络请求类 请求服务器数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 从JSON文件加载数据（或者从真实API获取）
        TJPFeedResponse *feedResponse = [self loadFeedDataFromJSONWithPage:page pageSize:20];

        if (feedResponse && feedResponse.isSuccess) {
            TJPLOG_INFO(@"Feed响应解析成功: %@", feedResponse.debugDescription);

            // 打印Feed统计信息
            NSDictionary *stats = [feedResponse getFeedStatistics];
            TJPLOG_INFO(@"Feed统计信息: %@", stats);
            
            // 转换数据模型
            NSArray *cellModels = [self convertFeedsToModels:feedResponse.feeds];
            TJPBaseSectionModel *section = [[TJPBaseSectionModel alloc] initWithCellModels:cellModels];
            NSArray *sections = @[section];
            
            // 创建分页信息 - 两种分页方式的兼容
            TJPPaginationInfo *paginationInfo = [self createPaginationInfoFromResponse:feedResponse forPage:page];
            
            TJPLOG_INFO(@"请求成功 - %@", paginationInfo);

            if (completion) completion(sections, paginationInfo, nil);
            
        } else {
            NSString *errorMessage = feedResponse ? [NSString stringWithFormat:@"服务器错误: %@ (code: %ld)", feedResponse.message, (long)feedResponse.code] :
            @"数据解析失败";
            NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                                 code:TJPViperErrorDataProcessFailed
                                             userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            if (completion) completion(nil, nil, error);
        }
    });
}

- (TJPPaginationInfo *)createPaginationInfoFromResponse:(TJPFeedResponse *)response forPage:(NSInteger)page {
    
    // 根据实际业务需求选择分页方式
    BOOL useCursorPagination = [self shouldUseCursorPaginationForPage:page];
    
    if (useCursorPagination) {
        // 游标分页方式
        return [self createCursorBasedPagination:response];
    } else {
        // 页码分页方式
        return [self createPageBasedPagination:response];
    }
}

- (BOOL)shouldUseCursorPaginationForPage:(NSInteger)page {
    // 这里可以根据业务逻辑决定使用哪种分页方式
    
    return page > 3;
}

- (TJPPaginationInfo *)createPageBasedPagination:(TJPFeedResponse *)response {
    TJPPaginationInfo *pagination = response.pagination;
    
    if (pagination.paginationType == TJPPaginationTypePageBased) {
        // 如果响应中已经是页码分页，直接使用
        return pagination;
    } else {
        // 如果响应是游标分页，但我们想转换为页码分页
        return [TJPPaginationInfo pageBasedPaginationWithPage:pagination.currentPage > 0 ? pagination.currentPage : 1
                                                      pageSize:pagination.pageSize
                                                    totalCount:response.totalCount > 0 ? response.totalCount : 100]; // 假设总数
    }
}

- (TJPPaginationInfo *)createCursorBasedPagination:(TJPFeedResponse *)response {
    TJPPaginationInfo *pagination = response.pagination;
    
    if (pagination.paginationType == TJPPaginationTypeCursorBased) {
        // 如果响应中已经是游标分页，直接使用
        return pagination;
    } else {
        // 如果响应是页码分页，但我们想转换为游标分页
        NSString *nextCursor = pagination.hasMore ? [NSString stringWithFormat:@"cursor_%ld", pagination.currentPage + 1] : nil;
        return [TJPPaginationInfo cursorBasedPaginationWithPageSize:pagination.pageSize
                                                         nextCursor:nextCursor
                                                            hasMore:pagination.hasMore];
    }
}

#pragma mark - 重写分页相关的工具方法
- (NSDictionary *)parametersForPage:(NSInteger)page {
    NSMutableDictionary *params = [[super commonParameters] mutableCopy];
    
    // 根据当前分页类型添加不同的参数
    if (self.currentPagination && self.currentPagination.paginationType == TJPPaginationTypeCursorBased) {
        // 游标分页参数
        params[@"cursor"] = self.currentPagination.nextCursor ?: @"";
        params[@"page_size"] = @(self.defaultPageSize);
    } else {
        // 页码分页参数
        params[@"page"] = @(page);
        params[@"page_size"] = @(self.defaultPageSize);
    }
    
    return [params copy];
}

- (TJPPaginationInfo *)extractPaginationFromResponse:(id)rawData {
    NSLog(@"[DEBUG] 服务端返回的原始分页数据: %@", rawData);

    if (![rawData isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSDictionary *responseDict = (NSDictionary *)rawData;
    NSDictionary *dataDict = responseDict[@"data"];
    NSDictionary *paginationDict = dataDict[@"pagination"];
    
    if (paginationDict) {
        return [TJPPaginationInfo paginationWithDict:paginationDict];
    }
    
    return nil;
}

- (TJPFeedResponse *)loadFeedDataFromJSONWithPage:(NSInteger)page pageSize:(NSInteger)pageSize {
    
    // 根据页码选择不同的JSON文件或生成不同的数据
    NSString *fileName = (page == 1) ? @"feedData" : [NSString stringWithFormat:@"feedData_page%ld", page];
    NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"json"];
    
    NSData *data = nil;
    if (path) {
        data = [NSData dataWithContentsOfFile:path];
    }
    
    // 如果没有找到对应页码的JSON文件，生成模拟数据
    if (!data) {
        NSLog(@"未找到对应页码的JSON文件");
        return [self generateMockFeedResponseForPage:page pageSize:pageSize];
    }
    
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        TJPLOG_ERROR(@"JSON解析错误: %@", error.localizedDescription);
        return [self generateMockFeedResponseForPage:page pageSize:pageSize];
    }
    
    TJPFeedResponse *response = [TJPFeedResponse feedResponseWithDict:jsonDict];
    
    if (!response || !response.isSuccess) {
        TJPLOG_ERROR(@"Feed响应解析失败或服务器返回错误");
        return [self generateMockFeedResponseForPage:page pageSize:pageSize];
    }
    
    return response;
}

- (TJPFeedResponse *)generateMockFeedResponseForPage:(NSInteger)page pageSize:(NSInteger)pageSize {
    // 生成模拟响应数据
    NSMutableArray *feeds = [NSMutableArray array];
    
    // 生成不同类型的Feed数据
    NSArray *feedTypes = @[@"news", @"image", @"video", @"userDynamic", @"product", @"ad"];
    
    for (NSInteger i = 0; i < pageSize; i++) {
        NSString *feedType = feedTypes[arc4random() % feedTypes.count];
        NSDictionary *feed = [self generateMockFeedOfType:feedType page:page index:i];
        [feeds addObject:feed];
    }
    
    // 创建分页信息
    BOOL hasMore = page < 5; // 假设总共5页
    NSInteger totalCount = 5 * pageSize;
    
    TJPPaginationInfo *pagination = [TJPPaginationInfo pageBasedPaginationWithPage:page
                                                                            pageSize:pageSize
                                                                          totalCount:totalCount];
    
    // 构造响应字典
    NSDictionary *responseDict = @{
        @"code": @200,
        @"message": @"success",
        @"data": @{
            @"feeds": feeds,
            @"pagination": [pagination toDictionary]
        }
    };
    
    // 使用增强的Response类创建响应
    TJPFeedResponse *response = [TJPFeedResponse feedResponseWithDict:responseDict];
    
    TJPLOG_INFO(@"生成模拟Feed响应: %@", response.debugDescription);
    
    return response;
}

- (NSArray *)convertFeedsToModels:(NSArray *)feedsArray {
    NSMutableArray *models = [NSMutableArray array];
    
    for (NSDictionary *feedDict in feedsArray) {
        TJPBaseCellModel *model = [self createModelFromDict:feedDict];
        if (model) {
            [models addObject:model];
        }
    }
    
    return models;
}

- (NSDictionary *)generateMockFeedOfType:(NSString *)feedType page:(NSInteger)page index:(NSInteger)index {
    NSString *feedId = [NSString stringWithFormat:@"mock_%@_%ld_%ld", feedType, page, index];
    
    if ([feedType isEqualToString:@"news"]) {
        return @{
            @"type": @"news",
            @"id": feedId,
            @"title": [NSString stringWithFormat:@"模拟新闻标题 - 第%ld页第%ld条", page, index+1],
            @"summary": @"这是一条模拟的新闻摘要内容，展示了新闻的主要信息...",
            @"imageUrl": @"https://example.com/mock_news_image.jpg",
            @"publishTime": @"刚刚",
            @"source": @"模拟新闻源",
            @"readCount": @(arc4random() % 10000)
        };
    } else if ([feedType isEqualToString:@"image"]) {
        return @{
            @"type": @"image",
            @"id": feedId,
            @"title": [NSString stringWithFormat:@"精美图片集 - 第%ld页第%ld条", page, index+1],
            @"imageUrls": @[
                @"https://example.com/mock_image1.jpg",
                @"https://example.com/mock_image2.jpg",
                @"https://example.com/mock_image3.jpg"
            ],
            @"likes": @(arc4random() % 1000),
            @"comments": @(arc4random() % 100),
            @"description": @"这是一组精美的图片，展示了美丽的风景"
        };
    } else if ([feedType isEqualToString:@"video"]) {
        return @{
            @"type": @"video",
            @"id": feedId,
            @"title": [NSString stringWithFormat:@"精彩视频 - 第%ld页第%ld条", page, index+1],
            @"coverUrl": @"https://example.com/mock_video_cover.jpg",
            @"videoUrl": @"https://example.com/mock_video.mp4",
            @"duration": @"05:30",
            @"playCount": @(arc4random() % 50000),
            @"author": @"视频创作者"
        };
    } else if ([feedType isEqualToString:@"userDynamic"]) {
        return @{
            @"type": @"userDynamic",
            @"id": feedId,
            @"userName": [NSString stringWithFormat:@"用户%ld", index+1],
            @"userAvatar": @"https://example.com/mock_avatar.jpg",
            @"content": [NSString stringWithFormat:@"这是第%ld页第%ld条用户动态，分享一些有趣的内容...", page, index+1],
            @"images": @[@"https://example.com/dynamic_image.jpg"],
            @"publishTime": @"2小时前",
            @"likes": @(arc4random() % 500),
            @"comments": @(arc4random() % 50)
        };
    } else if ([feedType isEqualToString:@"product"]) {
        return @{
            @"type": @"product",
            @"id": feedId,
            @"name": [NSString stringWithFormat:@"热门商品 - 第%ld页第%ld条", page, index+1],
            @"price": @(199.99 + (arc4random() % 800)),
            @"originalPrice": @(299.99 + (arc4random() % 1000)),
            @"imageUrl": @"https://example.com/mock_product.jpg",
            @"rating": @(4.0 + (arc4random() % 10) / 10.0),
            @"sales": @(arc4random() % 5000),
            @"tags": @[@"热销", @"包邮", @"正品保证"]
        };
    } else if ([feedType isEqualToString:@"ad"]) {
        return @{
            @"type": @"ad",
            @"id": feedId,
            @"title": [NSString stringWithFormat:@"精品广告 - 第%ld页第%ld条", page, index+1],
            @"subtitle": @"限时优惠，不容错过",
            @"imageUrl": @"https://example.com/mock_ad.jpg",
            @"actionText": @"立即查看",
            @"actionUrl": @"https://example.com/ad_landing"
        };
    }
    
    // 默认返回news类型
    return @{
        @"type": @"news",
        @"id": feedId,
        @"title": @"默认新闻",
        @"summary": @"默认摘要",
        @"imageUrl": @"https://example.com/default.jpg",
        @"publishTime": @"刚刚",
        @"source": @"默认来源",
        @"readCount": @100
    };
}

#pragma mark - Build CellModel
- (TJPBaseCellModel *)createModelFromDict:(NSDictionary *)dict {
    NSString *type = dict[@"type"];
    
    if ([type isEqualToString:@"news"]) {
        return [self createNewsModelFromDict:dict];
    } else if ([type isEqualToString:@"image"]) {
        return [self createImageModelFromDict:dict];
    } else if ([type isEqualToString:@"video"]) {
        return [self createVideoModelFromDict:dict];
    } else if ([type isEqualToString:@"userDynamic"]) {
        return [self createUserDynamicModelFromDict:dict];
    } else if ([type isEqualToString:@"product"]) {
        return [self createProductModelFromDict:dict];
    } else if ([type isEqualToString:@"ad"]) {
        return [self createAdModelFromDict:dict];
    }
    
    return nil;
}

- (TJPNewsCellModel *)createNewsModelFromDict:(NSDictionary *)dict {
    TJPNewsCellModel *model = [[TJPNewsCellModel alloc] init];
    model.newsId = dict[@"id"];
//    model.type = @"news";
    model.title = dict[@"title"];
    model.summary = dict[@"summary"];
    model.imageUrl = dict[@"imageUrl"];
    model.publishTime = dict[@"publishTime"];
    model.source = dict[@"source"];
    model.readCount = [dict[@"readCount"] integerValue];
    model.selectedCommand = self.selectedNewsCommand;
    return model;
}

- (TJPImageCellModel *)createImageModelFromDict:(NSDictionary *)dict {
    TJPImageCellModel *model = [[TJPImageCellModel alloc] init];
    model.imageId = dict[@"id"];
//    model.type = @"image";
    model.title = dict[@"title"];
    model.imageUrls = dict[@"imageUrls"];
    model.likes = [dict[@"likes"] integerValue];
    model.comments = [dict[@"comments"] integerValue];
    model.imageDescription = dict[@"description"];
    model.selectedCommand = self.selectedImageCommand;
    return model;
}

- (TJPVideoCellModel *)createVideoModelFromDict:(NSDictionary *)dict {
    TJPVideoCellModel *model = [[TJPVideoCellModel alloc] init];
    model.videoId = dict[@"id"];
//    model.type = @"video";
    model.title = dict[@"title"];
    model.coverUrl = dict[@"coverUrl"];
    model.videoUrl = dict[@"videoUrl"];
    model.duration = dict[@"duration"];
    model.playCount = [dict[@"playCount"] integerValue];
    model.author = dict[@"author"];
    model.selectedCommand = self.selectedVideoCommand;
    return model;
}

- (TJPUserDynamicCellModel *)createUserDynamicModelFromDict:(NSDictionary *)dict {
    TJPUserDynamicCellModel *model = [TJPUserDynamicCellModel yy_modelWithDictionary:dict];

//    TJPUserDynamicCellModel *model = [[TJPUserDynamicCellModel alloc] init];
//    model.userId = dict[@"id"];
//    model.type = @"userDynamic";
//    model.userName = dict[@"userName"];
//    model.userAvatar = dict[@"userAvatar"];
//    model.content = dict[@"content"];
//    model.images = dict[@"images"];
//    model.publishTime = dict[@"publishTime"];
//    model.likes = [dict[@"likes"] integerValue];
//    model.comments = [dict[@"comments"] integerValue];
    model.selectedCommand = self.selectedUserDynamicCommand;
    return model;
}

- (TJPProductCellModel *)createProductModelFromDict:(NSDictionary *)dict {
    TJPProductCellModel *model = [[TJPProductCellModel alloc] init];
    model.productId = dict[@"id"];
//    model.type = @"product";
    model.name = dict[@"name"];
    model.price = [dict[@"price"] floatValue];
    model.originalPrice = [dict[@"originalPrice"] floatValue];
    model.imageUrl = dict[@"imageUrl"];
    model.rating = [dict[@"rating"] floatValue];
    model.sales = [dict[@"sales"] integerValue];
    model.tags = dict[@"tags"];
    model.selectedCommand = self.selectedProductCommand;
    return model;
}

- (TJPAdCellModel *)createAdModelFromDict:(NSDictionary *)dict {
    TJPAdCellModel *model = [TJPAdCellModel yy_modelWithDictionary:dict];
//    TJPAdCellModel *model = [[TJPAdCellModel alloc] init];
//    model.adId = dict[@"id"];
//    model.type = @"ad";
//    model.title = dict[@"title"];
//    model.subtitle = dict[@"subtitle"];
//    model.imageUrl = dict[@"imageUrl"];
//    model.actionText = dict[@"actionText"];
//    model.actionUrl = dict[@"actionUrl"];
    model.selectedCommand = self.selectedAdCommand;
    return model;
}

#pragma mark - Commands

//- (RACCommand<TJPVIPERDemoCellModel *,NSObject *> *)selectedDemoDetilCommand {
//    if (nil == _selectedDemoDetilCommand) {
//        @weakify(self)
//        _selectedDemoDetilCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPVIPERDemoCellModel * _Nullable input) {
//            @strongify(self)
//            [self.navigateToPageSubject sendNext:input];
//            return [RACSignal empty];
//        }];
//    }
//    return _selectedDemoDetilCommand;
//}

- (RACCommand *)selectedNewsCommand {
    if (!_selectedNewsCommand) {
        @weakify(self)
        _selectedNewsCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPNewsCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedNewsCommand;
}

- (RACCommand *)selectedImageCommand {
    if (!_selectedImageCommand) {
        @weakify(self)
        _selectedImageCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPImageCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedImageCommand;
}

- (RACCommand *)selectedVideoCommand {
    if (!_selectedVideoCommand) {
        @weakify(self)
        _selectedVideoCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPVideoCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedVideoCommand;
}

- (RACCommand *)selectedUserDynamicCommand {
    if (!_selectedUserDynamicCommand) {
        @weakify(self)
        _selectedUserDynamicCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPUserDynamicCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedUserDynamicCommand;
}

- (RACCommand *)selectedProductCommand {
    if (!_selectedProductCommand) {
        @weakify(self)
        _selectedProductCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPProductCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedProductCommand;
}

- (RACCommand *)selectedAdCommand {
    if (!_selectedAdCommand) {
        @weakify(self)
        _selectedAdCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(TJPAdCellModel * _Nullable input) {
            @strongify(self)
            [self.navigateToPageSubject sendNext:input];
            return [RACSignal empty];
        }];
    }
    return _selectedAdCommand;
}

@end
