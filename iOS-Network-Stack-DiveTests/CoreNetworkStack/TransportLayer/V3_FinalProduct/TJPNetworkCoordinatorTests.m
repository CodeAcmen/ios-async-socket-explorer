//
//  TJPNetworkCoordinatorTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import <XCTest/XCTest.h>
#import <Reachability/Reachability.h>

#import "TJPNetworkCoordinator.h"
#import "TJPNetworkConfig.h"
#import "TJPSessionProtocol.h"



@interface TJPNetworkCoordinatorTests : XCTestCase

@property (nonatomic, strong) TJPNetworkConfig *mockConfig;


@end

@implementation TJPNetworkCoordinatorTests

- (void)setUp {
        
    TJPNetworkConfig *config = [[TJPNetworkConfig alloc] init];
    config.maxRetry = 3;
    config.baseDelay = 1.0;
    config.heartbeat = 5.0;
}

- (void)tearDown {
    self.mockConfig = nil;
}

- (void)testCreateSessionWithConfiguration {
    // 创建期望，确保异步操作完成后再进行断言
    XCTestExpectation *expectation = [self expectationWithDescription:@"Session added to sessionMap"];

    // 创建会话
    id<TJPSessionProtocol> session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:self.mockConfig];
    
    
    // 验证 session 不为空
    XCTAssertNotNil(session, @"Session should not be nil after creation.");
    
    // 使用 dispatch_barrier_async 确保 sessionMap 更新后触发期望
    dispatch_barrier_async([TJPNetworkCoordinator shared].ioQueue, ^{
        // 触发期望，表示 sessionMap 更新完成
        [expectation fulfill];
    });
    
    // 等待期望
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // 验证 sessionMap 中有一个会话
    XCTAssertEqual([TJPNetworkCoordinator shared].sessionMap.count, 1, @"SessionMap should have 1 session.");
}





- (void)testUpdateAllSessionsState {
    // 创建期望，等待会话状态更新
    XCTestExpectation *expectation = [self expectationWithDescription:@"Waiting for session state update"];

    // 创建一个会话
    __block id<TJPSessionProtocol> session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:self.mockConfig];
    
    // 更新所有会话的状态
    [[TJPNetworkCoordinator shared] updateAllSessionsState:TJPConnectStateDisconnected];

    // 在更新状态完成后，触发期望
    dispatch_async(dispatch_get_main_queue(), ^{
        session = [[TJPNetworkCoordinator shared].sessionMap objectEnumerator].nextObject;
        
        // 验证会话的状态是否更新
        XCTAssertEqualObjects(session.connectState, TJPConnectStateDisconnected, @"Session state should be updated to Disconnected.");

        // 完成期望
        [expectation fulfill];
    });

    // 等待期望
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
