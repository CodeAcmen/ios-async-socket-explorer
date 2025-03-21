//
//  TJPNETErrorHandler.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//

#import "TJPNETErrorHandler.h"
#import "TJPNETError.h"
#import "TJPNetworkManagerV1.h"
#import "JZNetworkDefine.h"

@implementation TJPNETErrorHandler

+ (void)handleError:(NSError *)error inManager:(TJPNetworkManagerV1 *)manager {
    switch ((TJPNETErrorCode)error.code) {
        case TJPNETErrorHeartbeatTimeout:
            [manager scheduleReconnect];
            break;
        case TJPNETErrorInvalidProtocol:
            [manager resetConnection];
            break;
        default:
            [self postNotificationForError:error];
            break;
    }
    
    // TODO 后续接入AOP日志
    NSLog(@"Network Error: %@", error.localizedDescription);
}

+ (void)postNotificationForError:(NSError *)error {
    NSDictionary *userInfo = @{
        @"error": error,
        @"timestamp": [NSDate date]
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkFatalErrorNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

@end
