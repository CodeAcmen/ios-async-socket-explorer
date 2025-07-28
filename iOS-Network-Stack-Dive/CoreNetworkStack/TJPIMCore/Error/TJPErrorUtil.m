//
//  TJPErrorUtil.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/14.
//

#import "TJPErrorUtil.h"

// 实现网络层错误域
NSString * const TJPNetworkErrorDomain = @"com.tjp.network.error";


@implementation TJPErrorUtil
+ (NSError *)errorWithCode:(TJPNetworkError)code description:(NSString *)description userInfo:(NSDictionary *)userInfo {
    NSMutableDictionary *errorInfo = userInfo ? [NSMutableDictionary dictionaryWithDictionary:userInfo] : [NSMutableDictionary dictionary];
    
    // 确保有错误描述
    if (description) {
        errorInfo[NSLocalizedDescriptionKey] = description;
    }
    
    return [NSError errorWithDomain:TJPNetworkErrorDomain code:code userInfo:errorInfo];
}

+ (NSError *)errorWithCode:(TJPNetworkError)code description:(NSString *)description failureReason:(NSString *)failureReason {
    NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
    
    if (description) {
        errorInfo[NSLocalizedDescriptionKey] = description;
    }
    
    if (failureReason) {
        errorInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    }
    
    return [NSError errorWithDomain:TJPNetworkErrorDomain code:code userInfo:errorInfo];
}

+ (TJPNetworkError)networkErrorFromTLVError:(TJPTLVParseError)tlvError {
    switch (tlvError) {
        case TJPTLVParseErrorNone:
            return TJPErrorNone;
        case TJPTLVParseErrorIncompleteTag:
            return TJPErrorTLVIncompleteTag;
        case TJPTLVParseErrorIncompleteLength:
            return TJPErrorTLVIncompleteLength;
        case TJPTLVParseErrorIncompleteValue:
            return TJPErrorTLVIncompleteValue;
        case TJPTLVParseErrorNestedTooDeep:
            return TJPErrorTLVNestedTooDeep;
        case TJPTLVParseErrorDuplicateTag:
            return TJPErrorTLVDuplicateTag;
        case TJPTLVParseErrorInvalidNestedTag:
            return TJPErrorTLVParseError;
        default:
            return TJPErrorUnknown;
    }
}

@end
