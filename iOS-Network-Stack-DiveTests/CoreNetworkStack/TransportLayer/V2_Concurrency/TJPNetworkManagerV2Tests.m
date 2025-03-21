//
//  TJPNetworkManagerV2Tests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <XCTest/XCTest.h>
#import "TJPNetworkManagerV2.h"


@interface TJPNetworkManagerV2Tests : XCTestCase
@property (nonatomic, strong) TJPNetworkManagerV2 *networkManager;

@end

@implementation TJPNetworkManagerV2Tests

- (void)setUp {
    self.networkManager = [TJPNetworkManagerV2 shared];

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


#pragma mark - 并发问题测试
- (void)testConcurrentPendingMessagesAccess {
    //并发修改 pendingMessages
    XCTestExpectation *expectation = [self expectationWithDescription:@"并发访问 pendingMessages"];

    dispatch_queue_t concurrentQueue = dispatch_queue_create("test.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);

    //10000个线程同时对pendingMessages进行访问
    for (int i = 0; i < 10000; i++) {
        dispatch_async(concurrentQueue, ^{
            NSNumber *key = @(i);
            NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];

            //并发安全写入
            [self.networkManager addPendingMessage:data forSequence:key.unsignedIntegerValue];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertGreaterThan(self.networkManager.pendingMessages.count, 0, @"pendingMessages 没有被正确修改");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
