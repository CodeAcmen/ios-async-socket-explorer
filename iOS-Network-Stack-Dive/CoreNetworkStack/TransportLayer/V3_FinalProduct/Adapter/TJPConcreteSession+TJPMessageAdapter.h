//
//  TJPConcreteSession+TJPMessageAdapter.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPConcreteSession.h"
#import "TJPMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPConcreteSession (TJPMessageAdapter)

/// 发送消息
- (void)sendMessage:(id<TJPMessage>)message;


@end

NS_ASSUME_NONNULL_END
