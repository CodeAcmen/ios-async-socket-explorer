//
//  TJPDynamicHeartbeatTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/24.
//

#import <XCTest/XCTest.h>
#import "TJPDynamicHeartbeat.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkConfig.h"
#import "TJPSequenceManager.h"
#import "TJPNetworkCondition.h"

@interface TJPDynamicHeartbeatTests : XCTestCase
@property (nonatomic, strong) TJPSequenceManager *seqManager;
@property (nonatomic, strong) TJPDynamicHeartbeat *heartbeatManager;
@property (nonatomic, strong) TJPConcreteSession *mockSession;


@end

@implementation TJPDynamicHeartbeatTests

- (void)setUp {
    TJPNetworkConfig *config = [[TJPNetworkConfig alloc] init];
    config.heartbeat = 5.0;
    self.mockSession = [[TJPConcreteSession alloc] initWithConfiguration:config];
    self.seqManager = [[TJPSequenceManager alloc] init];
    self.heartbeatManager = [[TJPDynamicHeartbeat alloc] initWithBaseInterval:config.heartbeat seqManager:self.seqManager];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}



- (void)testAdjustIntervalWithNetworkCondition {
    [self.heartbeatManager startMonitoringForSession:self.mockSession];

    TJPNetworkCondition *excellentCondition = [[TJPNetworkCondition alloc] init];
    // Excellent RTT
    excellentCondition.roundTripTime = 50;
    // Low packet loss
    excellentCondition.packetLossRate = 1.0;
    [self.heartbeatManager adjustIntervalWithNetworkCondition:excellentCondition];
    
    XCTAssertEqual(self.heartbeatManager.currentInterval, 4.0, @"Interval should decrease for excellent network condition");

    
    // Test with Poor network condition
    TJPNetworkCondition *poorCondition = [[TJPNetworkCondition alloc] init];
    // High RTT
    poorCondition.roundTripTime = 900;
    // High packet loss
    poorCondition.packetLossRate = 20.0;
    [self.heartbeatManager adjustIntervalWithNetworkCondition:poorCondition];
    
    XCTAssertEqual(self.heartbeatManager.currentInterval, 60.0, @"Interval should increase for poor network condition");
}

- (void)testHeartbeatACKNowledgedForSequence {
    uint32_t sequence = 1234;
    
    [self.heartbeatManager.pendingHeartbeats setObject:[NSDate date] forKey:@(sequence)];
    
    [self.heartbeatManager heartbeatACKNowledgedForSequence:sequence];
    
    XCTAssertNil(self.heartbeatManager.pendingHeartbeats[@(sequence)], @"Heartbeat should be removed after ACK is received");
}


- (void)testHeartbeatACKNowledgedForSequence_highConcurrency {
    const NSInteger concurrencyCount = 10000;
    
    // 使用异步队列来模拟并发
    dispatch_queue_t queue = dispatch_queue_create("com.test.heartbeat.concurrent", DISPATCH_QUEUE_CONCURRENT);
    
    // 创建期望对象，确保所有操作完成后再进行验证
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent operations completed"];
    
    // 在并发情况下添加序列号到 pendingHeartbeats
    dispatch_apply(concurrencyCount, queue, ^(size_t i) {
        // 随机生成序列号并添加到 pendingHeartbeats
        uint32_t newSequence = (uint32_t)(i + 1);
        
        // 模拟发送心跳包
        [self.heartbeatManager sendHeartbeat];
        
        // 模拟心跳ACK操作
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 随机选择一个序列号，并模拟收到 ACK
            uint32_t ackSequence = arc4random_uniform((uint32_t)concurrencyCount) + 1;
            [self.heartbeatManager heartbeatACKNowledgedForSequence:ackSequence];
            
            // 验证随机选择的序列号是否已被移除
            XCTAssertNil(self.heartbeatManager.pendingHeartbeats[@(ackSequence)], @"Heartbeat should be removed after ACK is received in high concurrency");
            
            // 完成期望
            if (i == concurrencyCount - 1) {
                [expectation fulfill];
            }
        });
    });
    
    // 等待期望的完成
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

// 模拟网络波动场景
- (void)testNetworkFluctuation {
    TJPDynamicHeartbeat *heartbeat = [[TJPDynamicHeartbeat alloc] initWithBaseInterval:60 seqManager:self.seqManager];
    
    // 第一阶段：优质网络（RTT=150ms, 丢包率0%）
    for (int i=0; i<10; i++) {
        [heartbeat.networkCondition updateRTTWithSample:150];
        [heartbeat.networkCondition updateLostWithSample:NO];
    }
    [heartbeat adjustIntervalWithNetworkCondition:heartbeat.networkCondition];
    XCTAssertEqual(heartbeat.currentInterval, 60 * (150/200)); // 期望45秒
    
    // 第二阶段：RTT恶化到800ms（触发Poor等级）
    for (int i=0; i<10; i++) {
        [heartbeat.networkCondition updateRTTWithSample:800];
    }
    [heartbeat adjustIntervalWithNetworkCondition:heartbeat.networkCondition];
    XCTAssertEqual(heartbeat.currentInterval, 60 * 2.5); // 期望150秒
    
    // 第三阶段：高丢包率（20%）
    for (int i=0; i<10; i++) {
        [heartbeat.networkCondition updateLostWithSample:(i < 2)]; // 20%丢包
    }
    [heartbeat adjustIntervalWithNetworkCondition:heartbeat.networkCondition];
    XCTAssertEqual(heartbeat.currentInterval, 60 * 2.5); // 仍为Poor等级，保持150秒
}





- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
