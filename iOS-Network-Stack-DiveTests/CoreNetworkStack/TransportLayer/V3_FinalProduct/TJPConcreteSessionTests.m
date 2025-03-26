//
//  TJPConcreteSessionTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPConcreteSession.h"
#import "TJPMockFinalVersionTCPServer.h"
#import "TJPNetworkConfig.h"
#import "TJPConnectStateMachine.h"
#import "TJPSessionDelegate.h"



@interface TJPConcreteSessionTests : XCTestCase <TJPSessionDelegate>

@property (nonatomic, strong) TJPMockFinalVersionTCPServer *mockServer;
@property (nonatomic, strong) TJPConcreteSession *session;
@property (nonatomic, strong) XCTestExpectation *connectionExpectation;
@property (nonatomic, strong) XCTestExpectation *dataExpectation;
@property (nonatomic, strong) XCTestExpectation *stateChangeExpectation;


@property (nonatomic, copy) NSArray<TJPConnectState> *expectedStateSequence;
@property (nonatomic, assign) NSUInteger currentStateIndex;


@end

@implementation TJPConcreteSessionTests

- (void)setUp {
    self.mockServer = [[TJPMockFinalVersionTCPServer alloc] init];
    [self.mockServer startWithPort:54321];
    
    TJPNetworkConfig *config = [[TJPNetworkConfig alloc] init];
    config.maxRetry = 3;
    config.baseDelay = 1.0;
    config.heartbeat = 5.0;
    self.session = [[TJPConcreteSession alloc] initWithConfiguration:config];
    self.session.delegate = self;
       
}

- (void)tearDown {
    [self.mockServer stop];
    self.mockServer = nil;
    self.session = nil;
    
    [super tearDown];
}


#pragma mark - TJPSessionDelegate
- (void)session:(id<TJPSessionProtocol>)session didReceiveData:(NSData *)data {
    if (self.dataExpectation) {
        NSString *receivedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([receivedString isEqualToString:@"test message"]) {
            [self.dataExpectation fulfill];
        }
    }
}

- (void)session:(id<TJPSessionProtocol>)session stateChanged:(TJPConnectState)state {
    NSLog(@"State changed to: %@", state);
    
    // 状态顺序验证
    if (self.expectedStateSequence) {
        if (self.currentStateIndex < self.expectedStateSequence.count) {
            TJPConnectState expectedState = self.expectedStateSequence[self.currentStateIndex];
            XCTAssertEqualObjects(state, expectedState);
            self.currentStateIndex++;
        }
    }
    
    // 连接成功处理
    if ([state isEqualToString:TJPConnectStateConnected] && self.connectionExpectation) {
        [self.connectionExpectation fulfill];
    }
}

#pragma mark - 测试用例
- (void)testConnectionStateFlow {
    // 定义期望的状态变化顺序
    self.expectedStateSequence = @[
        TJPConnectStateConnecting,
        TJPConnectStateConnected
    ];
    self.currentStateIndex = 0;
    
    self.stateChangeExpectation = [self expectationWithDescription:@"Should go through correct state sequence"];
    self.connectionExpectation = [self expectationWithDescription:@"Connection should succeed"];
    
    [self.session connectToHost:@"127.0.0.1" port:54321];
    
    // 设置延迟检查状态顺序
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.currentStateIndex == self.expectedStateSequence.count) {
            [self.stateChangeExpectation fulfill];
        }
    });
    
    // 使用 XCTest 自带的 waitForExpectations 方法
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testAllConnectionState{
    // 初始状态应为 Disconnected
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateDisconnected);
    
    // 1. 发送 Connect 事件
    [self.session.stateMachine sendEvent:TJPConnectEventConnect];
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateConnecting);
    
    // 2. 模拟连接成功
    [self.session.stateMachine sendEvent:TJPConnectEventConnectSuccess];
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateConnected);
    
    // 3. 正常断开流程
    [self.session.stateMachine sendEvent:TJPConnectEventDisconnect];
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateDisconnecting);
    
    // 4. 断开完成
    [self.session.stateMachine sendEvent:TJPConnectEventDisconnectComplete];
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateDisconnected);
    
    // 5. 测试强制断开
    [self.session.stateMachine sendEvent:TJPConnectEventConnect]; // 进入 Connecting
    [self.session.stateMachine sendEvent:TJPConnectEventForceDisconnect];
    XCTAssertEqualObjects(self.session.stateMachine.currentState, TJPConnectStateDisconnected);
}

- (void)testDataTransmissionWithACK {
    XCTestExpectation *connectionExpectation = [self expectationWithDescription:@"Connected"];
    XCTestExpectation *dataExpectation = [self expectationWithDescription:@"Should receive data and ack"];
    
    // 监听连接状态变化
    [self.session.stateMachine onStateChange:^(TJPConnectState  _Nonnull oldState, TJPConnectState  _Nonnull newState) {
        if ([newState isEqualToString:TJPConnectStateConnected]) {
            [connectionExpectation fulfill];
        }
    }];
    
    // 开始连接
    [self.session connectToHost:@"127.0.0.1" port:54321];

    // 等待连接成功
    [self waitForExpectations:@[connectionExpectation] timeout:5.0];

    // 发送测试数据
    [self.session sendData:[@"test message" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Mock服务器处理
    __block BOOL serverReceived = NO;
    __block BOOL didFulfill = NO;
    self.mockServer.didReceiveDataHandler = ^(NSData *data, uint32_t seq) {
        NSLog(@"Received data with sequence: %u", seq);  // 调试日志，确保数据接收到了
        
        serverReceived = YES;
        
        // 发送 ACK
        [self.mockServer sendACKForSequence:seq toSocket:self.mockServer.connectedSockets.firstObject];
        NSLog(@"Sent ACK for sequence: %u", seq);  // 调试日志，确保 ACK 被发送
        
        // 触发期望
        if (!didFulfill) {
            didFulfill = YES;
            NSLog(@"Fulfilling dataExpectation for sequence: %u", seq);
            [dataExpectation fulfill];
        }
    };

    
    // 等待数据 ACK
    [self waitForExpectations:@[dataExpectation] timeout:10.0];
    XCTAssertTrue(serverReceived, "Server did not receive data");
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
