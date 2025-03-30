//
//  TJPLogger.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import "TJPLogger.h"
#import "TJPLogModel.h"
#import "TJPNetworkDefine.h"

@interface TJPLogger ()

@end

@implementation TJPLogger {
    dispatch_queue_t _logQueue;
}

+ (instancetype)shared {
    static TJPLogger *instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (instancetype)init {
    if (self = [super init]) {
        _logQueue = dispatch_queue_create("com.tjp.logger.logQuee", DISPATCH_QUEUE_SERIAL);
        _traceId = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)log:(TJPLogModel *)log {
    dispatch_async(self->_logQueue, ^{
        NSString *logStr = [NSString stringWithFormat:@"日志记录 [TraceID: %@] - %@.%@ 耗时:%.2fms 参数:%@", self.traceId, log.clsName, log.methodName, log.executeTime * 1000, log.arguments];
        
        TJPLOG_INFO(@"- %@", logStr);
    });
}

@end
