//
//  TJPNetworkConditionTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPNetworkCondition.h"

@interface TJPNetworkConditionTests : XCTestCase

@property (nonatomic, strong) TJPNetworkCondition *condition;

@end

@implementation TJPNetworkConditionTests

- (void)setUp {
    self.condition = [[TJPNetworkCondition alloc] init];
}



- (void)testQualityLevel {
    TJPNetworkCondition *condition = [[TJPNetworkCondition alloc] init];
    
    // 测试 RTT 和丢包率正常的情况
    condition.roundTripTime = 50.0;
    condition.packetLossRate = 1.0;
    XCTAssertEqual(condition.qualityLevel, TJPNetworkQualityExcellent, @"网络质量评估错误（良好网络）");
    
    // 测试较差的 RTT 和丢包率
    condition.roundTripTime = 250.0;
    condition.packetLossRate = 5.0;
    XCTAssertEqual(condition.qualityLevel, TJPNetworkQualityGood, @"网络质量评估错误（普通网络）");
    
    // 测试较差的网络
    condition.roundTripTime = 500.0;
    condition.packetLossRate = 10.0;
    XCTAssertEqual(condition.qualityLevel, TJPNetworkQualityFair, @"网络质量评估错误（差网络）");
    
    // 测试非常差的网络
    condition.roundTripTime = 800.0;
    condition.packetLossRate = 20.0;
    XCTAssertEqual(condition.qualityLevel, TJPNetworkQualityPoor, @"网络质量评估错误（差网络）");
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
