//
//  TJPConcreteSession+TJPMessageAdapter.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPConcreteSession+TJPMessageAdapter.h"

@implementation TJPConcreteSession (TJPMessageAdapter)

- (void)sendMessage:(id<TJPMessage>)message {
    NSData *tlvData = [message tlvData];
    [self sendData:tlvData];
}

@end
