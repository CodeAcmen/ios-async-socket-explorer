//
//  TJPNetworkManagerTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/20.
//  

#import <XCTest/XCTest.h>
#import "TJPNetworkManagerV1.h"

@interface TJPNetworkManagerTests : XCTestCase

@property (nonatomic, strong) TJPNetworkManagerV1 *networkManager;


@end

@implementation TJPNetworkManagerTests

- (void)setUp {
    self.networkManager = [TJPNetworkManagerV1 shared];
}

- (void)tearDown {
}

#pragma mark - 基础功能测试
- (void)testNetworkConnection {
    XCTestExpectation *expectation = [self expectationWithDescription:@"等待连接"];

    [self.networkManager connectToHost:@"tcpbin.com" port:4242];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(self.networkManager.isConnected, @"连接失败");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testSendData {
    //测试数据发送
    XCTestExpectation *expectation = [self expectationWithDescription:@"发送数据"];

    NSData *testData = [@"Hello, TJPNetworkManager!" dataUsingEncoding:NSUTF8StringEncoding];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.networkManager sendData:testData];
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark - 并发问题测试
- (void)testConcurrentPendingMessagesAccess {
    //并发修改 pendingMessages
    XCTestExpectation *expectation = [self expectationWithDescription:@"并发访问 pendingMessages"];

    dispatch_queue_t concurrentQueue = dispatch_queue_create("test.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);

    //1000个线程同时对pendingMessages进行访问 导致崩溃
    for (int i = 0; i < 1000; i++) {
        dispatch_async(concurrentQueue, ^{
            NSNumber *key = @(i);
            NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];

            // 多线程会导致崩溃
            self.networkManager.pendingMessages[key] = data;
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertGreaterThan(self.networkManager.pendingMessages.count, 0, @"pendingMessages 没有被正确修改");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testConcurrentIsConnectedAccessWithDispatchApply {
    XCTestExpectation *expectation = [self expectationWithDescription:@"并发修改 isConnected"];

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    dispatch_apply(10000, concurrentQueue, ^(size_t i) {
        self.networkManager.isConnected = (i % 2 == 0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(self.networkManager.isConnected == YES || self.networkManager.isConnected == NO, @"isConnected 状态异常");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testConcurrentSequenceAccess {
    //并发修改 `_currentSequence`
    XCTestExpectation *expectation = [self expectationWithDescription:@"并发访问 _currentSequence"];

    dispatch_queue_t concurrentQueue = dispatch_queue_create("test.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);

    for (int i = 0; i < 1000; i++) {
        dispatch_async(concurrentQueue, ^{
            (self.networkManager.currentSequence)++;  // 可能出现竞争条件
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertGreaterThan(self.networkManager.currentSequence, 0, @"_currentSequence 可能未正确递增");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
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
