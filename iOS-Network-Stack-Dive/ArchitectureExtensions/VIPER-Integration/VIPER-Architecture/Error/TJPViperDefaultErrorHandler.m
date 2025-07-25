//
//  TJPViperDefaultErrorHandler.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/25.
//

#import "TJPViperDefaultErrorHandler.h"
#import "TJPViperErrorHandlingStrategy.h"

@implementation TJPViperDefaultErrorHandler

+ (instancetype)sharedHandler {
    static TJPViperDefaultErrorHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TJPViperDefaultErrorHandler alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _retryCountMap = [NSMutableDictionary dictionary];
        _showDebugInfo = NO;
#ifdef DEBUG
        _showDebugInfo = YES;
#endif
    }
    return self;
}

- (void)handleError:(NSError *)error
         inContext:(UIViewController *)context
        completion:(void(^)(BOOL shouldRetry))completion {
    
    TJPViperErrorHandlingStrategy *strategy;
    
    // 判断错误来源，选择不同的处理策略
    if ([error.domain isEqualToString:TJPViperErrorDomain]) {
        // 应用层错误 - 直接处理
        strategy = [TJPViperErrorHandlingStrategy strategyForViperError:(TJPViperError)error.code];
        [self processErrorWithStrategy:strategy error:error inContext:context completion:completion];
        
    } else {
        // 非应用层错误 - 委托给对应的错误处理器或回调上层决定
        if ([self.delegate respondsToSelector:@selector(viperErrorHandler:shouldHandleExternalError:inContext:completion:)]) {
            [self.delegate viperErrorHandler:self
                      shouldHandleExternalError:error
                                      inContext:context
                                     completion:completion];
        } else {
            // 默认处理：转换为未知应用层错误
            NSError *viperError = [self createViperErrorWithCode:TJPViperErrorUnknown
                                                     description:@"外部错误"];
            strategy = [TJPViperErrorHandlingStrategy strategyForViperError:TJPViperErrorUnknown];
            [self processErrorWithStrategy:strategy error:viperError inContext:context completion:completion];
        }
    }
}

// 提取错误处理核心逻辑
- (void)processErrorWithStrategy:(TJPViperErrorHandlingStrategy *)strategy
                           error:(NSError *)error
                       inContext:(UIViewController *)context
                      completion:(void(^)(BOOL shouldRetry))completion {
    
    // 生成重试键（基于错误域和错误码）
    NSString *retryKey = [NSString stringWithFormat:@"%@_%ld", error.domain, (long)error.code];
    NSInteger currentRetryCount = [self.retryCountMap[retryKey] integerValue];
    
    // 判断是否可以重试
    if (strategy.shouldRetry && currentRetryCount < strategy.maxRetryCount) {
        [self showRetryAlertWithStrategy:strategy
                                   error:error
                               inContext:context
                              completion:^(BOOL userWantsRetry) {
            if (userWantsRetry) {
                self.retryCountMap[retryKey] = @(currentRetryCount + 1);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(strategy.retryDelay * NSEC_PER_SEC)),
                             dispatch_get_main_queue(), ^{
                    completion(YES);
                });
            } else {
                [self.retryCountMap removeObjectForKey:retryKey];
                completion(NO);
            }
        }];
    } else {
        // 不可重试或达到最大重试次数
        [self.retryCountMap removeObjectForKey:retryKey];
        [self showErrorAlertWithStrategy:strategy error:error inContext:context];
        completion(NO);
    }
}

- (NSError *)createViperErrorWithCode:(TJPViperError)errorCode
                          description:(nullable NSString *)description {
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: description ?: @"应用错误"
    };
    
    return [NSError errorWithDomain:TJPViperErrorDomain
                               code:errorCode
                           userInfo:userInfo];
}

- (void)resetErrorState {
    [self.retryCountMap removeAllObjects];
}

#pragma mark - Private Methods

- (void)showRetryAlertWithStrategy:(TJPViperErrorHandlingStrategy *)strategy
                             error:(NSError *)error
                         inContext:(UIViewController *)context
                        completion:(void(^)(BOOL userWantsRetry))completion {
    
    NSString *message = [self buildAlertMessage:strategy error:error];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        completion(NO);
    }];
    
    UIAlertAction *retryAction = [UIAlertAction actionWithTitle:strategy.actionTitle
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        completion(YES);
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:retryAction];
    
    [context presentViewController:alert animated:YES completion:nil];
}

- (void)showErrorAlertWithStrategy:(TJPViperErrorHandlingStrategy *)strategy
                             error:(NSError *)error
                         inContext:(UIViewController *)context {
    
    NSString *message = [self buildAlertMessage:strategy error:error];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:strategy.actionTitle
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        if (strategy.needsSpecialHandling) {
            [self handleSpecialAction:strategy inContext:context];
        }
    }];
    
    [alert addAction:okAction];
    [context presentViewController:alert animated:YES completion:nil];
}

- (NSString *)buildAlertMessage:(TJPViperErrorHandlingStrategy *)strategy error:(NSError *)error {
    NSMutableString *message = [NSMutableString stringWithString:strategy.userMessage];
    
    if (strategy.recoverySuggestion) {
        [message appendFormat:@"\n\n%@", strategy.recoverySuggestion];
    }
    
    if (self.showDebugInfo) {
        [message appendFormat:@"\n\n[Debug] %@ (Domain: %@, Code: %ld)",
         error.localizedDescription, error.domain, (long)error.code];
    }
    
    return message;
}

- (void)handleSpecialAction:(TJPViperErrorHandlingStrategy *)strategy inContext:(UIViewController *)context {
    if ([strategy.actionTitle isEqualToString:@"重新登录"] || [strategy.actionTitle isEqualToString:@"去登录"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TJPViperShouldReloginNotification" object:nil];
    } else if ([strategy.actionTitle isEqualToString:@"去更新"]) {
        // 跳转应用商店
        NSURL *appStoreURL = [NSURL URLWithString:@"itms-apps://itunes.apple.com/app/idXXXXXXXX"];
        [[UIApplication sharedApplication] openURL:appStoreURL options:@{} completionHandler:nil];
    } else if ([strategy.actionTitle isEqualToString:@"联系客服"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TJPViperShouldContactSupportNotification" object:nil];
    }
}

@end
