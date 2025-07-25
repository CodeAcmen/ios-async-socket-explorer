//
//  TJPViperBaseInteractorImpl.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import <Foundation/Foundation.h>
#import "TJPViperBaseInteractorProtocol.h"
#import "TJPViperErrorDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPViperBaseInteractorImpl : NSObject <TJPViperBaseInteractorProtocol>


// 快速定义错误
- (NSError *)createErrorWithCode:(TJPViperError)errorCode description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END
