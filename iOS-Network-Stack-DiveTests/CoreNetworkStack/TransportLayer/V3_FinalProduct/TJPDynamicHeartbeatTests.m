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

- (void)testStartMonitoringForSession {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Heartbeat sent"];

    [self.heartbeatManager startMonitoringForSession:self.mockSession];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertNotNil(self.heartbeatManager.lastHeartbeatTime, @"Heartbeat time should not be nil after sending");
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:6.0 handler:nil];
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
    // 测试1000个并发操作
    const NSInteger concurrencyCount = 1000;
    
    // 在并发情况下添加序列号到 pendingHeartbeats
    dispatch_queue_t queue = dispatch_queue_create("com.test.heartbeat.concurrent", DISPATCH_QUEUE_CONCURRENT);
    
    // 用 XCTestExpectation 来确保所有的操作完成后再进行验证
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent operations completed"];
    
    // 添加多个并发操作来模拟并发访问
    dispatch_apply(concurrencyCount, queue, ^(size_t i) {
        // 随机生成序列号并添加到 pendingHeartbeats
        uint32_t newSequence = (uint32_t)(i + 1);
        [self.heartbeatManager.pendingHeartbeats setObject:[NSDate date] forKey:@(newSequence)];
    });
    
    // 模拟心跳 ACK 收到的操作
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 随机选择一个序列号，并模拟收到 ACK
        uint32_t ackSequence = arc4random_uniform((uint32_t)concurrencyCount) + 1;
        [self.heartbeatManager heartbeatACKNowledgedForSequence:ackSequence];
        
        // 验证随机选择的序列号是否已被移除
        XCTAssertNil(self.heartbeatManager.pendingHeartbeats[@(ackSequence)], @"Heartbeat should be removed after ACK is received in high concurrency");
        
        [expectation fulfill]; // 操作完成，通知测试框架
    });

    // 等待期望的完成
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
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
