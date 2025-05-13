//
//  TJPSequenceManagerTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPSequenceManager.h"


@interface TJPSequenceManagerTests : XCTestCase
@property (nonatomic, strong) TJPSequenceManager *seqManager;

@end


@implementation TJPSequenceManagerTests

- (void)setUp {
    self.seqManager = [[TJPSequenceManager alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testNextSeq {
    // 1. 测试初始值
    uint32_t seq1 = [self.seqManager nextSequenceForCategory:TJPMessageCategoryNormal];
    XCTAssertEqual(seq1, 1, @"序列号应从1开始");

    // 2. 测试普通递增
    uint32_t seq2 = [self.seqManager nextSequenceForCategory:TJPMessageCategoryNormal];
    XCTAssertEqual(seq2, 2, @"序列号应递增");

    // 3. 测试循环逻辑（直接设置到边界值）
    // 模拟 _sequence 已经达到 UINT32_MAX
    [self.seqManager resetSequence];
    [self.seqManager setValue:@(UINT32_MAX) forKey:@"_sequence"];

    uint32_t seqAfterMax = [self.seqManager nextSequenceForCategory:TJPMessageCategoryNormal];
    XCTAssertEqual(seqAfterMax, 1, @"达到最大值后应循环回1");
}


- (void)testResetSequence {
    TJPSequenceManager *manager = [[TJPSequenceManager alloc] init];
    
    // 测试递增后
    [manager nextSequenceForCategory:TJPMessageCategoryNormal];
    [manager nextSequenceForCategory:TJPMessageCategoryNormal];
    uint32_t seqBeforeReset = [manager nextSequenceForCategory:TJPMessageCategoryNormal];
    XCTAssertEqual(seqBeforeReset, 3, @"序列号应该递增到3");

    // 测试重置
    [manager resetSequence];
    uint32_t seqAfterReset = [manager nextSequenceForCategory:TJPMessageCategoryNormal];
    XCTAssertEqual(seqAfterReset, 1, @"重置后序列号应该从1开始");
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
