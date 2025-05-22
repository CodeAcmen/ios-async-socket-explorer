//
//  TJPNetworkManagerV1.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//  1.0版本的网络核心是一个能用但存在并发问题的管理类  仅仅用于学习演示
//   **并发问题**
//     - `pendingMessages` 是 `NSMutableDictionary`，多线程访问时可能会崩溃。
//     - `_currentSequence` 不是线程安全的，多线程操作可能导致序列号重复或丢失。
//     - `isConnected` 虽然是 `atomic`，但仍然在高并发情况下存在竞态条件。
//
//   **断线重连机制问题**
//     - `scheduleReconnect` 逻辑可能导致重复连接，特别是在 `reachableBlock` 回调中。
//
//   **数据解析问题**
//     - `parseBuffer` 在高并发情况下可能出现数据解析不完整的问题。
//     - `isParsingHeader` 状态可能导致数据处理异常。


#import <Foundation/Foundation.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPNetworkManagerV1 : NSObject <GCDAsyncSocketDelegate> {
    //当前序列号
//    NSUInteger _currentSequence;
}

//声明成属性用于单元测试
@property (nonatomic, assign) NSUInteger currentSequence;
//待确认消息
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSData *> *pendingMessages;


@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (atomic, assign) BOOL isConnected;

+ (instancetype)shared;
/// 连接方法
- (void)connectToHost:(NSString *)host port:(uint16_t)port;
/// 发送消息
- (void)sendData:(NSData *)data;

/// 重连策略
- (void)scheduleReconnect;
/// 重置连接
- (void)resetConnection;

@end

NS_ASSUME_NONNULL_END
