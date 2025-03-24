//
//  TJPConcreteSession.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//  会话类 核心之一

#import <Foundation/Foundation.h>
#import "TJPSessionProtocol.h"
#import "TJPSessionDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class TJPNetworkConfig;
@interface TJPConcreteSession : NSObject <TJPSessionProtocol>

@property (nonatomic, weak) id<TJPSessionDelegate> delegate;

// 独立的sessionId
@property (nonatomic, copy) NSString *sessionId;


- (instancetype)initWithConfiguration:(TJPNetworkConfig *)config;

@end

NS_ASSUME_NONNULL_END
