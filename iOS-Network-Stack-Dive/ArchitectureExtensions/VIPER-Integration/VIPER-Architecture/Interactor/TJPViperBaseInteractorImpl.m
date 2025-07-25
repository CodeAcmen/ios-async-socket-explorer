//
//  TJPViperBaseInteractorImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseInteractorImpl.h"
#import "TJPNetworkDefine.h"
#import "TJPViperDefaultErrorHandler.h"

@implementation TJPViperBaseInteractorImpl
@synthesize navigateToPageSubject = _navigateToPageSubject, dataListUpdatedSignal = _dataListUpdatedSignal;

- (void)dealloc {
    TJPLogDealloc();
}

- (RACSubject *)navigateToPageSubject {
    if (!_navigateToPageSubject) {
        _navigateToPageSubject = [RACSubject subject];
    }
    return _navigateToPageSubject;
}


- (RACSubject<NSDictionary *> *)dataListUpdatedSignal {
    if (!_dataListUpdatedSignal) {
        _dataListUpdatedSignal = [RACSubject subject];
    }
    return _dataListUpdatedSignal;
}

- (void)imSendMessage:(id)message {
    
}


- (void)fetchDataForPageWithCompletion:(NSInteger)page success:(void (^)(NSArray * _Nullable, NSInteger))success failure:(void (^)(NSError * _Nullable))failure {
    //提供标准接口 子类需要重写此方法并实现具体的业务逻辑
    TJPLOG_INFO(@"BaseInteractor provide a standard interface - fetchDataForPageWithCompletion.");
    
    // 参数验证
    if (page <= 0) {
        NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                             code:TJPViperErrorBusinessLogicFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"页码必须大于0"}];
        failure(error);
        return;
    }
    
    
    
    if ([self isMemberOfClass:[TJPViperBaseInteractorImpl class]]) {
        // 如果是基类被直接调用，抛出标准的TJPNetworkError
        if ([self isMemberOfClass:[TJPViperBaseInteractorImpl class]]) {
            NSError *error = [NSError errorWithDomain:TJPViperErrorDomain
                                                 code:TJPViperErrorBusinessLogicFailed
                                             userInfo:@{NSLocalizedDescriptionKey: @"子类必须重写此方法"}];
            failure(error);
            return;
        }
    }
}

- (NSError *)createErrorWithCode:(TJPViperError)errorCode description:(NSString *)description {
    return [NSError errorWithDomain:TJPViperErrorDomain
                               code:errorCode
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"未知错误"}];
}


@end
