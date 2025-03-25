//
//  TJPConnectStateMachineTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPConnectStateMachine.h"

@interface TJPConnectStateMachineTests : XCTestCase

@end

@implementation TJPConnectStateMachineTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testAddTransitionFromStateToStateForEvent {
    TJPConnectStateMachine *stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    // 添加状态转换规则
    [stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    
    // 获取转换后的状态
    TJPConnectState newState = [stateMachine valueForKey:@"_transitions"][@"Disconnected:Connect"];
    
    // 验证是否添加成功
    XCTAssertEqual(newState, TJPConnectStateConnecting, @"状态转换规则没有正确添加");
}

- (void)testSendEvent {
    TJPConnectStateMachine *stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    // 添加状态转换规则
    [stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    
    // 触发事件
    [stateMachine sendEvent:TJPConnectEventConnect];
    
    // 获取当前状态
    TJPConnectState currentState = [stateMachine valueForKey:@"_currentState"];
    
    // 验证当前状态是否已正确转换
    XCTAssertEqual(currentState, TJPConnectStateConnecting, @"状态转换失败");
}

- (void)testOnStateChange {
    TJPConnectStateMachine *stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    // 设置期望
    XCTestExpectation *expectation = [self expectationWithDescription:@"State change callback"];
    
    // 添加状态变化回调
    [stateMachine onStateChange:^(TJPConnectState oldState, TJPConnectState newState) {
        // 验证状态变化是否正确
        XCTAssertEqual(oldState, TJPConnectStateDisconnected, @"旧状态错误");
        XCTAssertEqual(newState, TJPConnectStateConnecting, @"新状态错误");
        
        // 完成回调
        [expectation fulfill];
    }];
    
    // 添加状态转换规则
    [stateMachine addTransitionFromState:TJPConnectStateDisconnected toState:TJPConnectStateConnecting forEvent:TJPConnectEventConnect];
    
    // 触发事件
    [stateMachine sendEvent:TJPConnectEventConnect];
    
    // 等待期望完成
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testInvalidStateTransition {
    TJPConnectStateMachine *stateMachine = [[TJPConnectStateMachine alloc] initWithInitialState:TJPConnectStateDisconnected];
    
    // 触发无效事件（没有对应的状态转换）
    [stateMachine sendEvent:TJPConnectEventDisconnect];
    
    // 验证是否没有发生状态转换
    TJPConnectState currentState = [stateMachine valueForKey:@"_currentState"];
    XCTAssertEqual(currentState, TJPConnectStateDisconnected, @"无效状态转换未正确处理");
    
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
