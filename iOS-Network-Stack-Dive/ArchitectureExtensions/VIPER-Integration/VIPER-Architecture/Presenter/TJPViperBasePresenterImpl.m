//
//  TJPViperBasePresenterImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBasePresenterImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPViperBaseInteractorProtocol.h"
#import "TJPViperBaseRouterHandlerProtocol.h"
#import "TJPViperBaseCellModelProtocol.h"



@implementation TJPViperBasePresenterImpl

@synthesize viewUpdatedDataSignal = _viewUpdatedDataSignal;

- (RACSubject<NSDictionary *> *)viewUpdatedDataSignal {
    if (!_viewUpdatedDataSignal) {
        _viewUpdatedDataSignal = [RACSubject subject];
    }
    return _viewUpdatedDataSignal;
}

- (void)dealloc {
    TJPLogDealloc();
}



- (void)bindInteractorToPageSubjectWithView:(UIViewController *)vc {
    //此处vc使用weak修饰 防止循环引用出现
    __weak typeof(UIViewController *)weakVC = vc;
    @weakify(self)
    [[[[self.baseInteractor.navigateToPageSubject
      takeUntil:self.rac_willDeallocSignal]
      deliverOnMainThread]
      map:^id _Nullable(id<TJPViperBaseCellModelProtocol> model) {
          // 安全类型转换
          if (![model conformsToProtocol:@protocol(TJPViperBaseCellModelProtocol)]) {
              [NSException raise:NSInvalidArgumentException format:@"Invalid model type"];
          }
          return [model navigationModelForCell];
      }]
     subscribeNext:^(TJPNavigationModel * _Nullable model) {
        @strongify(self)
        if (!weakVC) {
            TJPLOG_ERROR(@"ViewController has been deallocated");
            return;
        }
        
        //信号订阅成功 交给路由管理
        TJPLOG_INFO(@"Received model for page: %@", model);

        [self.baseRouter handleNavigationLogicWithModel:model context:weakVC];
        TJPLOG_INFO(@"Navigation triggered with model: %@", model);
    }];
}

- (void)bindInteractorDataUpdateSubject {
    @weakify(self)
    [self.baseInteractor.dataListUpdatedSignal subscribeNext:^(NSDictionary *  _Nullable x) {
        TJPLOG_INFO(@"接收到Interactor层数据更新信号");
        @strongify(self)
        [self.viewUpdatedDataSignal sendNext:x];
    }];
}

- (void)imSendMessage:(id)message {
    [self.baseInteractor imSendMessage:message];
}


- (void)fetchInteractorDataForPage:(NSInteger)page success:(void (^)(NSArray * _Nonnull, NSInteger))success failure:(void (^)(NSError * _Nonnull))failure {
    [self.baseInteractor fetchDataForPageWithCompletion:page success:success failure:failure];
}



@end


