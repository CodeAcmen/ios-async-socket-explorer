//
//  TJPChatMessage.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import <UIKit/UIKit.h>
#import "TJPChatMessageDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPChatMessage : NSObject

@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) BOOL isFromSelf;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) TJPChatMessageType messageType; // 文本、图片等
@property (nonatomic, strong) UIImage *image; // 图片消息
@property (nonatomic, assign) TJPChatMessageStatus status; // 发送中、已发送、失败


@property (nonatomic, assign) uint32_t sequence;       // 消息序列号
@property (nonatomic, strong) NSDate *readTime; // 消息已读时间


@end

NS_ASSUME_NONNULL_END
