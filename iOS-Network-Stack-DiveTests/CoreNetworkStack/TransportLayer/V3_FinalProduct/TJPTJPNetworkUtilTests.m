//
//  TJPTJPNetworkUtilTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/25.
//

#import <XCTest/XCTest.h>
#import "TJPCoreTypes.h"
#import "TJPMessageBuilder.h"
#import "TJPNetworkUtil.h"



@interface TJPTJPNetworkUtilTests : XCTestCase

@end

@implementation TJPTJPNetworkUtilTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBuildPacketWithData {
    NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t sequence = 1234;
    TJPMessageType type = TJPMessageTypeNormalData;
    
    NSData *packet = [TJPMessageBuilder buildPacketWithMessageType:type sequence:sequence payload:data encryptType:TJPEncryptTypeNone compressType:TJPCompressTypeNone sessionID:@""];
    
    // 验证包的长度（协议头 + 数据）
    XCTAssertEqual(packet.length, sizeof(TJPFinalAdavancedHeader) + data.length, @"数据包的长度应该是协议头长度 + 数据长度");
    
    // 验证 CRC 校验
    TJPFinalAdavancedHeader *header = (TJPFinalAdavancedHeader *)packet.bytes;
    
    // 使用crc32ForData方法计算expectedChecksum
    uint32_t expectedChecksum = [TJPNetworkUtil crc32ForData:data];
    
    // 转换协议头的checksum为主机字节序，并进行比较
    XCTAssertEqual(ntohl(header->checksum), expectedChecksum, @"CRC 校验失败");
}

- (void)testCompressAndDecompressData {
    NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 压缩数据
    NSData *compressedData = [TJPNetworkUtil compressData:data];
    XCTAssertNotNil(compressedData, @"压缩后的数据不应为空");
    
    // 解压数据
    NSData *decompressedData = [TJPNetworkUtil decompressData:compressedData];
    XCTAssertNotNil(decompressedData, @"解压后的数据不应为空");
    
    // 验证解压后的数据是否与原始数据相同
    XCTAssertEqualObjects(decompressedData, data, @"解压后的数据与原始数据不一致");
}

- (void)testBase64EncodeDecode {
    NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 编码数据
    NSString *encodedString = [TJPNetworkUtil base64EncodeData:data];
    XCTAssertNotNil(encodedString, @"Base64 编码后的字符串不应为空");
    
    // 解码字符串
    NSData *decodedData = [TJPNetworkUtil base64DecodeString:encodedString];
    XCTAssertNotNil(decodedData, @"Base64 解码后的数据不应为空");
    
    // 验证解码后的数据是否与原始数据相同
    XCTAssertEqualObjects(decodedData, data, @"Base64 解码后的数据与原始数据不一致");
}

- (void)testDeviceIPAddress {
    NSString *ipAddress = [TJPNetworkUtil deviceIPAddress];
    
    XCTAssertNotNil(ipAddress, @"设备 IP 地址不应为空");
    XCTAssertTrue([TJPNetworkUtil isValidIPAddress:ipAddress], @"设备 IP 地址无效");
    
    // 测试有效的 IP 地址
    NSString *validIP = @"192.168.1.1";
    XCTAssertTrue([TJPNetworkUtil isValidIPAddress:validIP], @"有效的 IP 地址应该返回 YES");
    
    // 测试无效的 IP 地址
    NSString *invalidIP = @"999.999.999.999";
    XCTAssertFalse([TJPNetworkUtil isValidIPAddress:invalidIP], @"无效的 IP 地址应该返回 NO");
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
