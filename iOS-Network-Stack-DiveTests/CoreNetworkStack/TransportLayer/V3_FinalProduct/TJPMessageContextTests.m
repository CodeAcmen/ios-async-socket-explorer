//
//  TJPMessageContextTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/24.
//

#import <XCTest/XCTest.h>
#import "TJPMessageContext.h"
#import "TJPNetworkUtil.h"

@interface TJPMessageContextTests : XCTestCase

@end

@implementation TJPMessageContextTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testContextWithData_initialization {
    // 创建测试数据
    NSData *testData = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 创建 TJPMessageContext 实例
    TJPMessageContext *context = [TJPMessageContext contextWithData:testData seq:1 messageType:TJPMessageTypeNormalData encryptType:TJPEncryptTypeNone compressType:TJPCompressTypeNone sessionId:@""];
    
    // 验证 sendTime 是否为当前时间（使用近似匹配）
    XCTAssertNotNil(context.sendTime, @"sendTime should not be nil");
    
    // 验证 retryCount 是否为 0
    XCTAssertEqual(context.retryCount, 0, @"retryCount should be initialized to 0");
    
    // 验证 sequence 是否正确设置
    XCTAssertGreaterThan(context.sequence, 0, @"sequence should be greater than 0");
}


- (void)testBuildRetryPacket {
    // 创建测试数据
    NSData *testData = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 创建 TJPMessageContext 实例
    TJPMessageContext *context = [TJPMessageContext contextWithData:testData seq:1 messageType:TJPMessageTypeNormalData encryptType:TJPEncryptTypeNone compressType:TJPCompressTypeNone sessionId:@""];
    
    // 初始时的 retryCount
    NSInteger initialRetryCount = context.retryCount;
    
    // 调用 buildRetryPacket 方法
    NSData *retryPacket = [context buildRetryPacket];
    
    // 验证 retryCount 是否递增
    XCTAssertEqual(context.retryCount, initialRetryCount + 1, @"retryCount should be incremented");
    
    // 验证返回的数据包是否正确构建
    XCTAssertNotNil(retryPacket, @"retryPacket should not be nil");
    XCTAssertEqual(retryPacket.length, testData.length + sizeof(TJPFinalAdavancedHeader), @"retryPacket should have the correct length");
    
    // 验证数据包的头部是否正确
    TJPFinalAdavancedHeader *header = (TJPFinalAdavancedHeader *)retryPacket.bytes;
    XCTAssertEqual(ntohl(header->sequence), context.sequence, @"Sequence in retry packet should match context's sequence");
    XCTAssertEqual(header->msgType, htons(TJPMessageTypeNormalData), @"Message type should be normal data in retry packet");
    XCTAssertEqual(header->bodyLength, htonl((uint32_t)testData.length), @"Body length should match the original data's length");
    XCTAssertEqual(header->checksum, [TJPNetworkUtil crc32ForData:testData], @"Checksum should match the original data's checksum");
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
