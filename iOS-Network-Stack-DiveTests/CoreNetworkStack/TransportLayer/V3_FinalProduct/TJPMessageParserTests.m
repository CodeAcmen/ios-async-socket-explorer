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


- (void)testMaxNestedDepth {
    // 1. 测试有效嵌套深度（4层）
    NSData *validData = [self generateNestedTLVWithDepth:4];
    TJPFinalAdavancedHeader header = {0};
    header.magic = htonl(kProtocolMagic);
    header.bodyLength = htonl((uint32_t)validData.length);
    
    NSError *error = nil;
    TJPParsedPacket *packet = [TJPParsedPacket packetWithHeader:header
                                                      payload:validData
                                                      policy:TJPTLVTagPolicyRejectDuplicates
                                                maxNestedDepth:4
                                                        error:&error];
    // 断言解析成功
    XCTAssertNil(error, @"有效嵌套深度4应成功，错误: %@", error);
    XCTAssertNotNil(packet, @"packet不应为nil");
    
    // 验证嵌套深度
    __block NSUInteger nestedDepth = 0;
    id currentEntry = packet.tlvEntries[@0xFFFF];
    while ([currentEntry isKindOfClass:[NSDictionary class]]) {
        nestedDepth++;
        currentEntry = ((NSDictionary *)currentEntry)[@0xFFFF];
    }
    XCTAssertEqual(nestedDepth, 4, @"嵌套深度应为4，实际为%lu", nestedDepth);
    
    // 2. 测试无效嵌套深度（5层）
    NSData *invalidData = [self generateNestedTLVWithDepth:5];
    header.bodyLength = htonl((uint32_t)invalidData.length);

    // 断言解析失败
    XCTAssertNotNil(error, @"嵌套深度5应触发错误");
    XCTAssertEqualObjects(error.domain, @"TLVError", @"错误域名不符");
    XCTAssertEqual(error.code, TJPTLVParseErrorNestedTooDeep, @"错误码应为TJPTLVParseErrorNestedTooDeep");
}

- (NSData *)generateNestedTLVWithDepth:(NSUInteger)depth {
    NSMutableData *data = [NSMutableData data];
    
    // 递归生成嵌套TLV
    [self appendNestedTLVToData:data remainingDepth:depth];
    
    return [data copy];
}

- (void)appendNestedTLVToData:(NSMutableData *)data remainingDepth:(NSUInteger)remainingDepth {
    if (remainingDepth == 0) {
        // 最内层添加实际数据（例如用户ID）
        uint16_t tag = CFSwapInt16HostToBig(0x1001); // Tag=0x1001（用户ID）
        uint32_t length = CFSwapInt32HostToBig(5);   // Length=5
        [data appendBytes:&tag length:2];
        [data appendBytes:&length length:4];
        [data appendBytes:"Hello" length:5];         // Value="Hello"
        return;
    }
    
    // 外层添加嵌套TLV标记（例如0xFFFF）
    uint16_t tag = CFSwapInt16HostToBig(0xFFFF); // 嵌套保留Tag
    [data appendBytes:&tag length:2];
    
    // 预留Length位置，后续填充
    NSUInteger lengthOffset = data.length;
    [data appendBytes:&(uint32_t){0} length:4]; // 占位4字节
    
    // 递归生成子TLV
    [self appendNestedTLVToData:data remainingDepth:remainingDepth - 1];
    
    // 回填Length（整个子TLV的长度）
    uint32_t childLength = CFSwapInt32HostToBig((uint32_t)(data.length - lengthOffset - 4));
    [data replaceBytesInRange:NSMakeRange(lengthOffset, 4) withBytes:&childLength];
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
