//
//  TJPMessageParserTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPMessageParser.h"
#import "TJPParsedPacket.h"

@interface TJPMessageParserTests : XCTestCase

@end

@implementation TJPMessageParserTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testFeedData {
    TJPMessageParser *parser = [[TJPMessageParser alloc] init];
    
    // 输入数据
    NSData *data = [NSData dataWithBytes:"HelloWorld" length:10];
    
    // 添加数据到缓冲区
    [parser feedData:data];
    
    // 检查缓冲区内容是否正确
    XCTAssertEqual(parser.buffer.length, 10, @"缓冲区长度应该为10");
    XCTAssertEqualObjects(parser.buffer, data, @"缓冲区内容应该和输入数据一致");
}

- (void)testHasCompletePacket {
    TJPMessageParser *parser = [[TJPMessageParser alloc] init];
    
    // 构造一个有效的数据包头和内容
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.bodyLength = htonl(5);  // 设置消息体的长度为 5 字节
    NSData *headerData = [NSData dataWithBytes:&header length:sizeof(header)];
    NSData *bodyData = [NSData dataWithBytes:"Hello" length:5];  // 消息体
    
    // 添加数据到缓冲区
    [parser feedData:headerData];
    [parser feedData:bodyData];
    
    // 测试缓冲区是否已经包含一个完整的包
    XCTAssertTrue([parser hasCompletePacket], @"缓冲区应该包含一个完整的数据包");
}


- (void)testNextPacket {
    TJPMessageParser *parser = [[TJPMessageParser alloc] init];
    
    // 构造一个有效的数据包
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.bodyLength = htonl(5);  // 设置消息体的长度为 5 字节
    NSData *headerData = [NSData dataWithBytes:&header length:sizeof(header)];
    NSData *bodyData = [NSData dataWithBytes:"Hello" length:5];  // 消息体
    
    // 添加数据到缓冲区
    [parser feedData:headerData];
    [parser feedData:bodyData];
    
    // 测试是否正确解析数据包
    TJPParsedPacket *packet = [parser nextPacket];
    
    // 验证解析结果
    XCTAssertNotNil(packet, @"应该解析出一个数据包");
    XCTAssertEqual(packet.header.magic, htonl(kProtocolMagic), @"魔数校验失败");
    XCTAssertEqual(packet.payload.length, 5, @"消息体长度不正确");
    XCTAssertEqualObjects(packet.payload, bodyData, @"消息体内容不匹配");
}

- (void)testParseHeader {
    TJPMessageParser *parser = [[TJPMessageParser alloc] init];
    
    // 构造一个有效的数据包头
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);  // 设定魔数
    header.msgType = htons(TJPMessageTypeNormalData);  // 设置消息类型
    header.bodyLength = htonl(5);  // 设置消息体的长度为5字节
    NSData *headerData = [NSData dataWithBytes:&header length:sizeof(header)];
    
    // 添加数据到缓冲区
    [parser feedData:headerData];
    
    // 测试头部解析
    XCTAssertNoThrow([parser parseHeader], @"头部解析时不应抛出异常");
    XCTAssertEqual(parser.currentHeader.magic, htonl(kProtocolMagic), @"魔数校验失败");
}

- (void)testParseBody {
    TJPMessageParser *parser = [[TJPMessageParser alloc] init];
    
    // 构造一个有效的数据包头和内容
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.bodyLength = htonl(5);  // 消息体长度为 5 字节
    NSData *headerData = [NSData dataWithBytes:&header length:sizeof(header)];
    NSData *bodyData = [NSData dataWithBytes:"Hello" length:5];  // 消息体
    
    // 添加数据到缓冲区
    [parser feedData:headerData];
    [parser feedData:bodyData];
    
    // 测试解析消息体
    TJPParsedPacket *packet = [parser nextPacket];
    
    XCTAssertNotNil(packet, @"应该解析出一个数据包");
    XCTAssertEqualObjects(packet.payload, bodyData, @"消息体内容解析错误");
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
