//
//  TJPNavigationCoordinatorTests.m
//  iOS-Network-Stack-DiveTests
//
//  Created by 唐佳鹏 on 2025/4/1.
//

#import <XCTest/XCTest.h>
#import "TJPNavigationCoordinator.h"
#import "TJPViewPushHandler.h"
#import "OCMock/OCMock.h"

@interface TJPNavigationCoordinatorTests : XCTestCase

@end

@implementation TJPNavigationCoordinatorTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testHandlerRegistration {
    // Given
    TJPNavigationCoordinator *coordinator = [TJPNavigationCoordinator sharedInstance];
    id mockHandler = OCMProtocolMock(@protocol(TJPViperBaseRouterHandlerProtocol));
    
    // 创建一个期望值，用于同步测试
    XCTestExpectation *expectation = [self expectationWithDescription:@"Handler registration"];
    
    // When
    [coordinator registerHandler:mockHandler forRouteType:TJPNavigationRouteTypeViewPush];
    
    // 给异步队列一定的时间来完成注册
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Then
        id handler = [coordinator.handlers objectForKey:@(TJPNavigationRouteTypeViewPush)];
        XCTAssertEqualObjects(handler, mockHandler, @"处理器注册失败");
        
        // 完成期望值
        [expectation fulfill];
    });
    
    // 等待期望值完成
    [self waitForExpectations:@[expectation] timeout:1.0];
}



- (void)testSingleThreadRegistrationPerformance {
    TJPNavigationCoordinator *coordinator = [TJPNavigationCoordinator sharedInstance];
    NSArray<NSNumber *> *routeTypes = @[@1, @2, @3]; // 实际业务路由类型
    
    [self measureMetrics:@[XCTPerformanceMetric_WallClockTime]
               automaticallyStartMeasuring:NO
                             forBlock:^{
        // 预热缓存
        [coordinator registerHandler:[TJPViewPushHandler new] forRouteType:1];
        
        [self startMeasuring];
        
        // 正式测试
        for (int i = 0; i < 500; i++) {
            NSNumber *type = routeTypes[i % routeTypes.count];
            [coordinator registerHandler:[TJPViewPushHandler new]
                             forRouteType:type.integerValue];
        }
        
        [self stopMeasuring];
        
        // 清理
        [routeTypes enumerateObjectsUsingBlock:^(NSNumber *t, NSUInteger idx, BOOL * _Nonnull stop) {
            [coordinator unregisterHandlerForRouteType:t.integerValue];
        }];
    }];
}


- (void)testConcurrentRegistrationPerformance {
    TJPNavigationCoordinator *coordinator = [TJPNavigationCoordinator sharedInstance];
    NSArray<NSNumber *> *routeTypes = @[@1, @2, @3];
    
    [self measureBlock:^{
        dispatch_group_t group = dispatch_group_create();
        
        for (int i = 0; i < 1000; i++) {
            dispatch_group_enter(group);
            
            NSNumber *type = routeTypes[arc4random_uniform((uint32_t)routeTypes.count)];
            TJPViewPushHandler *handler = [TJPViewPushHandler new];
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                [coordinator registerHandler:handler forRouteType:type.integerValue];
                dispatch_group_leave(group);
            });
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    }];
}

- (void)testRegistrationMemorySafety {
    TJPNavigationCoordinator *coordinator = [TJPNavigationCoordinator sharedInstance];
    NSArray<NSNumber *> *routeTypes = @[@1, @2, @3];
    
    @autoreleasepool {
        for (int i = 0; i < 100; i++) {
            TJPViewPushHandler *handler = [TJPViewPushHandler new];
            [coordinator registerHandler:handler forRouteType:routeTypes[i%3].integerValue];
        }
    }
    
    // 验证handler是否被正确释放
    XCTestExpectation *checkExpectation = [self expectationWithDescription:@"MemoryCheck"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __block BOOL hasLeak = NO;
        [routeTypes enumerateObjectsUsingBlock:^(NSNumber *t, NSUInteger idx, BOOL * _Nonnull stop) {
            id handler = [coordinator handlerForRouteType:t.integerValue];
            if (handler) {
                hasLeak = YES;
                *stop = YES;
            }
        }];
        
        XCTAssertFalse(hasLeak, @"检测到内存泄漏");
        [checkExpectation fulfill];
    });
    
    [self waitForExpectations:@[checkExpectation] timeout:2];
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
