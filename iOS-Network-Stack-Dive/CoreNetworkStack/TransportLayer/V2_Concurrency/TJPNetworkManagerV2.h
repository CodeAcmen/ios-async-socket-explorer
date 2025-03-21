//
//  TJPNetworkManagerV2.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  2.0版本是解决了并发问题的单TCP长连接网络管理类  可用在小型项目/中型项目早期中 但单连接在现代中大型项目中会造成性能瓶颈
//  **并发问题解决思路**
//  使用GCD的串行队列管理数据收发与状态更新  没有使用加锁的核心原因: 简化并发控制逻辑,提升代码的执行效率与可维护性
//  关键修改代码见:
//  #pragma mark - Thread Safe Method
//  **方案选型对比**   
//  加锁:锁的粒度控制相对困难,更容易出现死锁或者串行过度化  多处加锁相对维护困难
//  gcd串行队列: 行队列的任务切换开销更小，避免了死锁、锁竞争等复杂问题
//  结果:单元测试万级并发量依然稳定运行
//
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPNetworkManagerV2 : NSObject <GCDAsyncSocketDelegate> {
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

//并发安全写入
- (void)addPendingMessage:(NSData *)data forSequence:(NSUInteger)sequence;

@end

NS_ASSUME_NONNULL_END
