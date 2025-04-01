//
//  TJPViperBasePresenterProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBasePresenterProtocol <NSObject>

/// 调度Interactor获取数据
/// - Parameters:
///   - page: 页数
///   - success: 成功回调
///   - failure: 失败回调
///   - callback: 回调
- (void)fetchInteractorDataForPage:(NSInteger)page
              success:(void (^)(NSArray *data, NSInteger totalPage))success
                 failure:(void (^)(NSError *error))failure;


/// 订阅Interactor中的跳转页面信号
- (void)bindInteractorToPageSubjectWithView:(UIViewController *)vc;

/// 订阅Interactor中数据更新信号
- (void)bindInteractorDataUpdateSubject;


/// presenter层透传刷新信号
@property (nonatomic, strong) RACSubject<NSDictionary *> *viewUpdatedDataSignal;



@optional

/// im发送消息方法
/// - Parameter message: 消息体
- (void)imSendMessage:(id)message;

@end

NS_ASSUME_NONNULL_END
