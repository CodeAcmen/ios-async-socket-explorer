//
//  TJPNetworkCoordinator.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  中心管理类 核心类之一

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"
#import "TJPSessionDelegate.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TJPSessionProtocol;
@class Reachability, TJPNetworkConfig;

@interface TJPNetworkCoordinator : NSObject <TJPSessionDelegate>

//@property (nonatomic, strong, readonly) id<TJPSessionProtocol> defaultSession;
@property (nonatomic, strong, readonly) NSMapTable<NSString *, id<TJPSessionProtocol>> *sessionMap;


@property (nonatomic, strong) Reachability *reachability;


/// I/O专用队列
@property (nonatomic, strong) dispatch_queue_t ioQueue;
/// 解析专用队列
@property (nonatomic, strong) dispatch_queue_t parseQueue;

/// 单例
+ (instancetype)shared;

/// 创建会话方法
- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config;
/// 统一更新所有会话状态
- (void)updateAllSessionsState:(TJPConnectState)state;

@end

NS_ASSUME_NONNULL_END
