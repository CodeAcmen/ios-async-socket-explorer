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
@class Reachability, TJPNetworkConfig, TJPLightweightSessionPool;

@interface TJPNetworkCoordinator : NSObject <TJPSessionDelegate>
/// 管理当前正在使用的会话 按sessionId索引
@property (nonatomic, strong, readonly) NSMapTable<NSString *, id<TJPSessionProtocol>> *sessionMap;

/// Session类型 为多路复用做支撑
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *sessionTypeMap;

/// 会话池 管理会话复用
@property (nonatomic, strong) TJPLightweightSessionPool *sessionPool;

/// 网络状态
@property (nonatomic, strong) Reachability *reachability;

/// session专用队列 串行:增删改查操作
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
/// 解析专用队列  串行：数据解析专用
@property (nonatomic, strong) dispatch_queue_t parseQueue;
/// 监控专用队列  串行：网络监控相关
@property (nonatomic, strong) dispatch_queue_t monitorQueue;





/// 单例
+ (instancetype)shared;

/// 创建会话方法
- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config;
/// 通过类型创建会话方法 多路复用必须使用此方法
- (id<TJPSessionProtocol>)createSessionWithConfiguration:(TJPNetworkConfig *)config type:(TJPSessionType)type;

/// 新增默认session配置方法
- (TJPNetworkConfig *)defaultConfigForSessionType:(TJPSessionType)type;

/// 统一更新所有会话状态
- (void)updateAllSessionsState:(TJPConnectState)state;
/// 统一管理重连
- (void)scheduleReconnectForSession:(id<TJPSessionProtocol>)session;
/// 移除会话
- (void)removeSession:(id<TJPSessionProtocol>)session;

@end

NS_ASSUME_NONNULL_END
