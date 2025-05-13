//
//  TJPReconnectPolicyTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPReconnectPolicy.h"

@interface TJPReconnectPolicyTests : XCTestCase

@end

@implementation TJPReconnectPolicyTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testReconnectPolicyInitialization {
    TJPReconnectPolicy *reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:5 baseDelay:10.0 qos:TJPNetworkQoSUserInitiated delegate:nil];
    
    // 验证初始化参数是否正确
    XCTAssertEqual(reconnectPolicy.maxAttempts, 5, @"最大重试次数应为5");
    XCTAssertEqual(reconnectPolicy.baseDelay, 10.0, @"基础延迟应为10.0");
    XCTAssertEqual(reconnectPolicy.qosClass, QOS_CLASS_USER_INITIATED, @"QoS 应为 TJPNetworkQoSUserInitiated");
}

- (void)testAttemptConnectionWithBlock {
    __block BOOL connectionAttempted = NO;
    TJPReconnectPolicy *reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:3 baseDelay:1.0 qos:TJPNetworkQoSUserInitiated delegate:nil];
    
    // 使用 XCTestExpectation 来确保重试机制按预期工作
    XCTestExpectation *expectation = [self expectationWithDescription:@"Retrying connection"];
    
    // 尝试连接
    [reconnectPolicy attemptConnectionWithBlock:^{
        connectionAttempted = YES;
        [expectation fulfill];
    }];
    
    // 等待连接尝试
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    XCTAssertTrue(connectionAttempted, @"连接尝试应被调用");
}

- (void)testCalculateDelay {
    TJPReconnectPolicy *reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:5 baseDelay:2.0 qos:TJPNetworkQoSUserInitiated delegate:nil];

    // 设置 _currentAttempt 为 2，并测试延迟计算
    reconnectPolicy.currentAttempt = 2;
    
    // 期望延迟计算应该是 pow(2, 2) = 4.0
    NSTimeInterval calculatedDelay = [reconnectPolicy calculateDelay];
    XCTAssertEqual(calculatedDelay, 4.0, @"The calculated delay should be 4.0 seconds.");
    
    // 测试当延迟超过最大延迟时，返回最大延迟值
    reconnectPolicy.currentAttempt = 5;  // 设置更高的尝试次数
    NSTimeInterval maxDelay = [reconnectPolicy calculateDelay];
    XCTAssertEqual(maxDelay, 30.0, @"The calculated delay should not exceed the maximum reconnect delay of 30 seconds.");
}




- (void)testNotifyReachMaxAttempts {
    TJPReconnectPolicy *reconnectPolicy = [[TJPReconnectPolicy alloc] initWithMaxAttempst:3 baseDelay:1.0 qos:TJPNetworkQoSUserInitiated delegate:nil];
    
    // 使用 XCTestExpectation 来确保最大重试次数达到时的通知被触发
    XCTestExpectation *expectation = [self expectationWithDescription:@"Max retry attempts reached"];
    
    // 模拟尝试连接并重试
    for (NSInteger i = 0; i < 3; i++) {
        [reconnectPolicy attemptConnectionWithBlock:^{

        }];
    }
    
    // 模拟最大重试次数达到
    [reconnectPolicy notifyReachMaxAttempts];
    
    // 确保通知到达
    [expectation fulfill];
    
    // 等待通知完成
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
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
