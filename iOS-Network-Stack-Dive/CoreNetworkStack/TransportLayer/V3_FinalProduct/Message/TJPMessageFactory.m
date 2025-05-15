//
//  TJPMessageFactory.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPMessageFactory.h"
#import <objc/runtime.h>
#import <mach-o/getsect.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <mach-o/ldsyms.h>


#import "TJPMessageProtocol.h"

@implementation TJPMessageFactory

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerAllMessages];
    });
}

+ (void)registerAllMessages {
    //在APP运行时通过 dladdr 和 getsectiondata 扫描所有注册的类
    Dl_info info;
    dladdr(&_mh_execute_header, &info);
    
    unsigned long size = 0;
    uintptr_t *section = (uintptr_t *)getsectiondata(info.dli_fbase, "__DATA", "TJPMessages", &size);
    
    for (int i = 0; i < size/sizeof(uintptr_t); i++) {
        const char *className = (const char *)section[i];
        Class cls = objc_getClass(className);
        if ([cls conformsToProtocol:@protocol(TJPMessageProtocol)]) {
            [self registerClass:cls];
        }
    }
}

+ (void)registerClass:(Class<TJPMessageProtocol>)messageClass {
    // 存储消息类型与类的映射
    [[self classMap] setObject:messageClass forKey:@([messageClass messageTag])];
}

+ (NSMutableDictionary *)classMap {
    static NSMutableDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = [NSMutableDictionary new]; });
    return map;
}

@end
