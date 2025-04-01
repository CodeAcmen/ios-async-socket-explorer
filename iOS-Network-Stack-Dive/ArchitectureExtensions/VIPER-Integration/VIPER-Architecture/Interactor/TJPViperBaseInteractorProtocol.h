//
//  TJPViperBaseInteractorProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>


NS_ASSUME_NONNULL_BEGIN

@protocol TJPViperBaseInteractorProtocol <NSObject>

/// 透传跳转需求
@property (nonatomic, strong) RACSubject *navigateToPageSubject;

/// 数据源更新需求
@property (nonatomic, strong) RACSubject<NSDictionary *> *dataListUpdatedSignal;





/// 获取数据
/// - Parameters:
///   - page: 页数
///   - success: 成功回调
///   - failure: 失败回调
- (void)fetchDataForPageWithCompletion:(NSInteger)page
                  success:(void (^)(NSArray * _Nullable data, NSInteger totalPage))success
                  failure:(void (^)(NSError * _Nullable error))failure;


@optional
- (void)imSendMessage:(id)message;

@end

NS_ASSUME_NONNULL_END
