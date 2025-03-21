//
//  TJPSession.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/20.
//  会话对象

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>
#import "TJPNetworkProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPSession : NSObject

//此处用weak避免循环引用
@property (nonatomic, weak) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSMutableData *parserBuffer;
@property (nonatomic, assign) TJPAdavancedHeader currentHeader;
@property (nonatomic, assign) BOOL isParsingHeader;
@property (nonatomic, strong) dispatch_queue_t parserQueue;

- (void)resetParser;

@end

NS_ASSUME_NONNULL_END
