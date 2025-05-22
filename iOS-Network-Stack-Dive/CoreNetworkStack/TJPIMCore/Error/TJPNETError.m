//
//  TJPNETError.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//

#import "TJPNETError.h"

@implementation TJPNETError


+ (instancetype)errorWithCode:(TJPNETErrorCode)code userInfo:(NSDictionary *)dict {
    return [[self alloc] initWithDomain:@"com.tjpnetwork.error" code:code userInfo:dict];
}

@end
