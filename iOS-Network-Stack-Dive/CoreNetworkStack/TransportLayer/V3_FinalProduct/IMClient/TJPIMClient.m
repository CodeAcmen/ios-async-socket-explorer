//
//  TJPIMClient.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPIMClient.h"
#import "TJPNetworkCoordinator.h"
#import "TJPConcreteSession.h"
#import "TJPNetworkConfig.h"


@interface TJPIMClient ()
@property (nonatomic, strong) TJPConcreteSession *session;


@end

@implementation TJPIMClient
+ (instancetype)shared {
    static TJPIMClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    TJPNetworkConfig *config = [TJPNetworkConfig configWithHost:host port:port maxRetry:5 heartbeat:15.0];
    self.session = (TJPConcreteSession *)[[TJPNetworkCoordinator shared] createSessionWithConfiguration:config];
    [self.session connectToHost:host port:port];
}

- (void)sendMessage:(id<TJPMessage>)message {
    NSData *tlvData = [message tlvData];
    [self.session sendData:tlvData];
}

- (void)disconnect {
    [self.session disconnectWithReason:TJPDisconnectReasonUserInitiated];
}
@end
