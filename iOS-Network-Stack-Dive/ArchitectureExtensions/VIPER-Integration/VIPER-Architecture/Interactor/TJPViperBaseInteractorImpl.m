//
//  TJPViperBaseInteractorImpl.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPViperBaseInteractorImpl.h"
#import "TJPNetworkDefine.h"

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
    
    if ([self isMemberOfClass:[TJPViperBaseInteractorImpl class]]) {
        NSAssert(NO, @"Subclass must override");
        failure([NSError errorWithDomain:@"VIPER" code:500 userInfo:nil]);
    }

    
}


@end
