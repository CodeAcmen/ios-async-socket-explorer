//
//  TJPTextMessage.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPTextMessage.h"
#import "TJPMessageSerializer.h"
#import "TJPCoreTypes.h"

/*
 利用 __attribute__((section)) 将类名写入 Mach-O 文件的 __DATA 段
 在程序启动时通过工厂加载
 */
__attribute__((used, section("__DATA,TJPMessages")))
static const char *kTJPTextMessageRegistration = "TJPTextMessage";

@implementation TJPTextMessage
- (instancetype)initWithText:(NSString *)text {
    if (self = [super init]) {
        _text = text;
    }
    return self;
}

+ (uint16_t)messageTag { return TJPContentTypeText; }

- (NSData *)tlvData {
    return [TJPMessageSerializer serializeText:self.text tag:[self.class messageTag]];
}

@end
