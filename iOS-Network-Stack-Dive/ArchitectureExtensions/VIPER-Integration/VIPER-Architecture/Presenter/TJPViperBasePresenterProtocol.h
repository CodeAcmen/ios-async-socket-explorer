//
//  TJPViperBasePresenterProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//  VIPER Presenter基础协议 定义了Presenter层的标准接口和职责

#import <UIKit/UIKit.h>
#import <ReactiveObjC/ReactiveObjC.h>

NS_ASSUME_NONNULL_BEGIN
@protocol TJPViperBaseViewControllerProtocol;

@protocol TJPViperBasePresenterProtocol <NSObject>

#pragma mark - 获取数据

/**
 * 获取分页数据
 * @param page 页码
 * @param success 成功回调
 * @param failure 失败回调
 */
- (void)fetchInteractorDataForPage:(NSInteger)page success:(void (^)(NSArray * _Nonnull data, NSInteger totalPage))success failure:(void (^)(NSError * _Nonnull error))failure;

#pragma mark - 信号绑定

/**
 * 绑定Interactor的页面跳转信号
 * @param contextProvider controller上下文
 */
- (void)bindInteractorToPageSubjectWithContextProvider:(id<TJPViperBaseViewControllerProtocol>)contextProvider;

/**
 * 绑定Interactor的数据更新信号
 */
- (void)bindInteractorDataUpdateSubject;

/**
 * presenter层透传刷新信号
 */
@property (nonatomic, strong) RACSubject<NSDictionary *> *viewUpdatedDataSignal;



#pragma mark - 生命周期管理

/**
 * Presenter初始化完成
 */
- (void)presenterDidInitialize;

/**
 * View即将出现
 */
- (void)viewWillAppear;

/**
 * View已经出现
 */
- (void)viewDidAppear;

/**
 * View即将消失
 */
- (void)viewWillDisappear;

/**
 * View已经消失
 */
- (void)viewDidDisappear;


/**
 * 获取当前业务状态
 */
- (NSDictionary *)currentBusinessState;

/**
 * 重置业务状态
 */
- (void)resetBusinessState;


/**
 * 处理用户交互事件
 * @param event 事件名称
 * @param data 事件数据
 */
- (void)handleUserInteraction:(NSString *)event withData:(nullable id)data;

/**
 * 处理用户输入验证
 * @param input 用户输入
 * @return 验证结果
 */
- (NSError * _Nullable)validateUserInput:(NSDictionary *)input;


@optional


/**
 * 处理深度链接
 * @param url 深度链接URL
 * @param parameters 参数
 */
- (BOOL)handleDeepLink:(NSURL *)url parameters:(NSDictionary *)parameters;

/**
 * 处理推送消息
 * @param notification 推送消息
 */
- (void)handlePushNotification:(NSDictionary *)notification;

/**
 * 数据预加载
 */
- (void)preloadData;

/**
 * 清理资源
 */
- (void)cleanup;



@end

NS_ASSUME_NONNULL_END
