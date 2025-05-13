//
//  TJPConnectStateMachineMetricsTest.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/4/9.
//

#import <XCTest/XCTest.h>
#import "TJPConnectStateMachine.h"
#import "TJPMetricsCollector.h"

@interface TJPConnectStateMachineMetricsTest : XCTestCase

@end

@implementation TJPConnectStateMachineMetricsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testStateDurationTracking {
    // 初始化状态机并设置初始状态为 Disconnected
    TJPConnectStateMachine *machine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    // 添加转换规则
    [machine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    [machine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    [machine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventConnectFailure];
    [machine addTransitionFromState:TJPConnectStateConnected toState:TJPConnectStateDisconnecting forEvent:TJPConnectEventDisconnect];
    [machine addTransitionFromState:TJPConnectStateDisconnecting toState:TJPConnectStateDisconnected forEvent:TJPConnectEventDisconnectComplete];

    XCTestExpectation *expectation = [self expectationWithDescription:@"State transition completed"];
    
    // 触发从 Disconnected -> Connecting 状态转换
    [machine sendEvent:TJPConnectEventConnect]; // -> Connecting
    NSLog(@"当前状态: %@", machine.currentState);
    
    // 延时 1 秒后触发 ConnectSuccess 事件，转到 Connected
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [machine sendEvent:TJPConnectEventConnectSuccess]; // -> Connected
        NSLog(@"当前状态: %@", machine.currentState);
        
        // 获取 Connecting 状态的持续时间
        NSTimeInterval duration = [[TJPMetricsCollector sharedInstance] averageStateDuration:TJPConnectStateConnecting];
        NSLog(@"Connecting 状态持续时间: %.2f 秒", duration);
        
        // 验证 Connecting 状态持续时间是否接近 1.0 秒
        XCTAssertTrue(fabs(duration - 1.0) < 0.05, @"持续时间误差应小于 50ms");
        
        // 触发期望，完成测试
        [expectation fulfill]; // 完成测试
    });
    
    // 等待期望，最大等待时间 1.5 秒
    [self waitForExpectationsWithTimeout:1.5 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Test failed: %@", error.localizedDescription);
        }
    }];
}


- (void)testHighFrequencyStateChanges {
    TJPConnectStateMachine *machine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    [machine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    [machine addTransitionFromState:TJPConnectStateConnecting toState:TJPConnectStateConnected forEvent:TJPConnectEventConnectSuccess];
    
    // 测量性能
    [self measureBlock:^{
        for (int i = 0; i < 10000; i++) {
            // 触发连接事件
            [machine sendEvent:TJPConnectEventConnect];
            // 立即触发连接成功事件，模拟连接过程中的状态变化
            [machine sendEvent:TJPConnectEventConnectSuccess];
        }
    }];
    
    // 验证事件的平均持续时间
    NSTimeInterval connectEventDuration = [[TJPMetricsCollector sharedInstance] averageEventDuration:TJPConnectEventConnect];
    NSTimeInterval connectSuccessEventDuration = [[TJPMetricsCollector sharedInstance] averageEventDuration:TJPConnectEventConnectSuccess];
    
    // 确保每个事件的持续时间大于零
    XCTAssertTrue(connectEventDuration > 0, @"Connect event should have non-zero duration");
    XCTAssertTrue(connectSuccessEventDuration > 0, @"ConnectSuccess event should have non-zero duration");
    
    // 进一步验证事件处理时间在合理范围内，可以根据具体业务逻辑调整
    XCTAssertTrue(connectEventDuration < 0.05, @"Connect event duration should be under 50ms");
    XCTAssertTrue(connectSuccessEventDuration < 0.05, @"ConnectSuccess event duration should be under 50ms");
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
