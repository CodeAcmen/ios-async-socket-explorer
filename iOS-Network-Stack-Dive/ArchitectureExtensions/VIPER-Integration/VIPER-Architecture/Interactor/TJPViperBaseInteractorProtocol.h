//
//  TJPViperBaseInteractorProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  VIPER Interactor基础协议  定义了Interactor层的标准接口和职责

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseInteractorProtocol <NSObject>

#pragma mark - 响应式信号
/// 透传跳转需求
@property (nonatomic, strong) RACSubject *navigateToPageSubject;

/// 数据源更新需求
@property (nonatomic, strong) RACSubject<NSDictionary *> *dataListUpdatedSignal;



#pragma mark - 获取数据
/**
 * 获取分页数据
 * @param page 页码
 * @param success 成功回调 (数据数组, 总页数)
 * @param failure 失败回调
 */
- (void)fetchDataForPageWithCompletion:(NSInteger)page success:(void (^)(NSArray * _Nullable data, NSInteger totalPage))success failure:(void (^)(NSError * _Nullable error))failure;


#pragma mark - 数据操作

/**
 * 创建数据
 * @param data 要创建的数据
 * @param completion 完成回调
 */
- (void)createData:(NSDictionary *)data completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion;

/**
 * 更新数据
 * @param dataId 数据ID
 * @param updateData 更新的数据
 * @param completion 完成回调
 */
- (void)updateDataWithId:(NSString *)dataId updateData:(NSDictionary *)updateData completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion;

/**
 * 删除数据
 * @param dataId 数据ID
 * @param completion 完成回调
 */
- (void)deleteDataWithId:(NSString *)dataId completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * 搜索数据
 * @param keyword 搜索关键词
 * @param filters 筛选条件
 * @param completion 完成回调
 */
- (void)searchDataWithKeyword:(NSString *)keyword filters:(NSDictionary *)filters completion:(void (^)(NSArray * _Nullable results, NSError * _Nullable error))completion;

#pragma mark - 缓存管理

/**
 * 清除指定缓存
 * @param cacheKey 缓存键
 */
- (void)clearCache:(NSString *)cacheKey;

/**
 * 清除所有缓存
 */
- (void)clearAllCache;

/**
 * 获取缓存大小
 * @return 缓存大小(字节)
 */
- (NSUInteger)getCacheSize;

#pragma mark - 状态同步

/**
 * 同步数据到服务器
 * @param completion 完成回调
 */
- (void)syncDataToServer:(void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * 从服务器同步数据
 * @param completion 完成回调
 */
- (void)syncDataFromServer:(void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * 实时数据订阅
 * @param topic 订阅主题
 * @param completion 完成回调
 */
- (void)subscribeToRealTimeData:(NSString *)topic completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/**
 * 取消实时数据订阅
 * @param topic 订阅主题
 */
- (void)unsubscribeFromRealTimeData:(NSString *)topic;

/**
 * 文件上传
 * @param fileData 文件数据
 * @param fileName 文件名
 * @param progress 进度回调
 * @param completion 完成回调
 */
- (void)uploadFile:(NSData *)fileData fileName:(NSString *)fileName progress:(void (^)(CGFloat progress))progress completion:(void (^)(NSString * _Nullable fileUrl, NSError * _Nullable error))completion;

/**
 * 获取配置信息
 * @param configKey 配置键
 * @return 配置值
 */
- (id _Nullable)getConfigValue:(NSString *)configKey;

/**
 * 业务规则验证
 * @param data 待验证数据
 * @return 验证错误，nil表示验证通过
 */
- (NSError * _Nullable)validateBusinessRules:(NSDictionary *)data;


@optional

@end

NS_ASSUME_NONNULL_END
