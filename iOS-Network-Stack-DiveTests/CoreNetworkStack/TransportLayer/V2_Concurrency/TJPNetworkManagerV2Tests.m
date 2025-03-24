//
//  TJPNetworkManagerV2Tests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <zlib.h>

#import "TJPConcurrentNetworkManager.h"
#import "TJPNetworkProtocol.h"
#import "TJPMockTCPServer.h"


@interface TJPNetworkManagerV2Tests : XCTestCase
@property (nonatomic, strong) TJPConcurrentNetworkManager *networkManager;

@property (nonatomic, strong) TJPMockTCPServer *server;


@end

@implementation TJPNetworkManagerV2Tests

- (void)setUp {
    self.networkManager = [TJPConcurrentNetworkManager shared];
}


#pragma mark - 基础功能测试
- (void)testNetworkConnection {
    XCTestExpectation *expectation = [self expectationWithDescription:@"等待连接"];

    [self.networkManager connectToHost:@"tcpbin.com" port:4242];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(self.networkManager.isConnected, @"连接失败");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testSendHeartbeat {
    XCTestExpectation *expectation = [self expectationWithDescription:@"心跳发送成功"];
    
    self.server = [[TJPMockTCPServer alloc] init];
    NSError *error = nil;
    XCTAssertTrue([self.server startOnPort:54321 error:&error]);

    [self.networkManager connectToHost:@"127.0.0.1" port:54321];

    self.networkManager.onSocketWrite = ^(NSData *data, long tag) {
        const TJPAdavancedHeader *header = (const TJPAdavancedHeader *)data.bytes;
        if (ntohs(header->msgType) == TJPMessageTypeHeartbeat) {
            XCTAssertNotNil(self.networkManager.pendingHeartbeats[@(ntohl(header->sequence))]);
            [expectation fulfill];
        }
    };

    [self waitForExpectationsWithTimeout:35 handler:nil];
}

- (void)testReceiveACK {
    XCTestExpectation *ackExpectation = [self expectationWithDescription:@"收到 ACK，消息已移除"];

    self.server = [[TJPMockTCPServer alloc] init];
    NSError *error = nil;
    XCTAssertTrue([self.server startOnPort:54321 error:&error]);

    [self.networkManager connectToHost:@"127.0.0.1" port:54321];

    // 发送数据后等 ACK
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *message = @"test ack";
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];

        NSUInteger sequenceBeforeSend = self.networkManager.currentSequence + 1;
        [self.networkManager sendData:data];

        // 等待一会儿，查看是否 ACK 被移除
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL exists = self.networkManager.pendingMessages[@(sequenceBeforeSend)] != nil;
            XCTAssertFalse(exists, @"ACK 收到后，pendingMessages 应该移除该序列号");
            [ackExpectation fulfill];
        });
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}



- (void)testFullSocketChainWithMockServer {
    XCTestExpectation *expect = [self expectationWithDescription:@"全链路消息解析"];

    self.server = [[TJPMockTCPServer alloc] init];
    NSError *error = nil;
    XCTAssertTrue([self.server startOnPort:54321 error:&error]);

    TJPConcurrentNetworkManager *manager = [TJPConcurrentNetworkManager shared];
    [manager resetParse];
    [manager connectToHost:@"127.0.0.1" port:54321];

    __block BOOL fulfilled = NO;
    self.networkManager.onMessageParsed = ^(NSString *payloadStr) {
        if (fulfilled) return;
        fulfilled = YES;
        
        XCTAssertEqualObjects(payloadStr, @"hello world");
        [expect fulfill];
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSData *packet = [self.server buildPacketWithMessage:@"hello world"];
        [self.server sendPacket:packet];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}


// 构造模拟数据包（符合协议）
- (NSData *)buildMockPacketWithMessage:(NSString *)message {
    TJPAdavancedHeader header = {0};
    NSData *payload = [message dataUsingEncoding:NSUTF8StringEncoding];

    header.magic = htonl(kProtocolMagic);
    header.msgType = htons(TJPMessageTypeNormalData);
    header.sequence = htonl(1);
    header.bodyLength = htonl((uint32_t)payload.length);

    uLong crc = crc32(0L, Z_NULL, 0);
    header.checksum = htonl((uint32_t)crc32(crc, [payload bytes], (uInt)[payload length]));

    NSMutableData *packet = [NSMutableData dataWithBytes:&header length:sizeof(header)];
    [packet appendData:payload];
    return packet;
}


#pragma mark - 并发问题测试
- (void)testConcurrentPendingMessagesAccess {
    //并发修改 pendingMessages
    XCTestExpectation *expectation = [self expectationWithDescription:@"并发访问 pendingMessages"];

    dispatch_queue_t concurrentQueue = dispatch_queue_create("test.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);

    //10000个线程同时对pendingMessages进行访问
    for (int i = 0; i < 10000; i++) {
        dispatch_async(concurrentQueue, ^{
            NSNumber *key = @(i);
            NSData *data = [@"Test Data" dataUsingEncoding:NSUTF8StringEncoding];

            //并发安全写入
            [self.networkManager addPendingMessage:data forSequence:key.unsignedIntegerValue];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertGreaterThan(self.networkManager.pendingMessages.count, 0, @"pendingMessages 没有被正确修改");
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
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
