//
//  TJPLoggerManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import "TJPLoggerManager.h"
#import "TJPLogger.h"
#import "TJPLogModel.h"
#import "TJPAspectCore.h"

@implementation TJPLoggerManager

// 注册日志的方法，封装日志配置和注册操作
+ (void)registerLogForTargetClass:(Class)targetClass targetSelector:(SEL)targetSelector triggers:(TJPLogTriggerPoint)triggers outputs:(TJPLogOutputOption)outputOption {

    TJPLogConfig config;
    config.targetClass = targetClass;
    config.targetSelector = targetSelector;

    [TJPAspectCore registerLogWithConfig:config
                                 trigger:triggers
                                 handler:^(TJPLogModel *log) {

        if (outputOption & TJPLogOutputOptionConsole) {
            [[TJPLogger shared] log:log];
        }

        if (outputOption & TJPLogOutputOptionFile) {
            [self saveLogToFile:log];
        }

        if (outputOption & TJPLogOutputOptionServer) {
            [self sendLogToServer:log];
        }
    }];
}

+ (void)removeLogForTargetClass:(Class)targetClass {
    [TJPAspectCore removeLogForClass:targetClass];
}


// 保存日志到文件
+ (void)saveLogToFile:(TJPLogModel *)log {
    // 获取沙盒 Documents 目录
    NSString *documentsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    
    // 日志文件路径
    NSString *logFilePath = [documentsPath stringByAppendingPathComponent:@"logs.txt"];
    
    // 创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 检查文件是否存在，不存在则创建文件
    if (![fileManager fileExistsAtPath:logFilePath]) {
        [fileManager createFileAtPath:logFilePath contents:nil attributes:nil];
    }
    
    // 生成日志内容
    NSString *logContent = [NSString stringWithFormat:@"[%@] %@: %f\n", log.clsName, log.methodName, log.executeTime];
    
    // 将日志追加到文件
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[logContent dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

// 发送日志到服务器
+ (void)sendLogToServer:(TJPLogModel *)log {
    // 假设服务器的日志上传接口为 POST 请求
    NSURL *url = [NSURL URLWithString:@"https://your-server.com/api/log"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    // 构造日志数据（可以根据实际需要选择合适的日志字段）
    NSDictionary *logDict = @{
        @"clsName" : log.clsName,
        @"methodName" : log.methodName,
        @"executeTime" : @(log.executeTime),
        @"traceID" : [TJPLogger shared].traceId ? [TJPLogger shared].traceId : @""
    };
    
    NSError *error;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:logDict options:0 error:&error];
    if (error) {
        NSLog(@"Error serializing log data: %@", error);
        return;
    }
    
    // 设置请求体
    [request setHTTPBody:bodyData];
    
    // 创建网络请求
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to send log to server: %@", error);
        } else {
            NSLog(@"Successfully sent log to server");
        }
    }];
    
    [dataTask resume];
}

@end
