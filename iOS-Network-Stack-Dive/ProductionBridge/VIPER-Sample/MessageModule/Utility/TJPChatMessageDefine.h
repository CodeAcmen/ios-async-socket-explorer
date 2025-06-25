//
//  TJPChatMessageDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#ifndef TJPChatMessageDefine_h
#define TJPChatMessageDefine_h

//************************************************************************
// Chat相关,后期增加防腐层后抽离出此文件
typedef NS_ENUM(NSUInteger, TJPChatMessageType) {
    TJPChatMessageTypeText = 0,        // 文本消息
    TJPChatMessageTypeImage = 1,       // 图片消息
    TJPChatMessageTypeAudio = 2,       // 语音消息
    TJPChatMessageTypeVideo = 3,       // 视频消息
    TJPChatMessageTypeFile = 4,        // 文件消息
    TJPChatMessageTypeLocation = 5,    // 位置消息
};

typedef NS_ENUM(NSUInteger, TJPChatMessageStatus) {
    TJPChatMessageStatusNone = 0,
    TJPChatMessageStatusSending = 1,   // 发送中
    TJPChatMessageStatusSent = 2,      // 已发送
    TJPChatMessageStatusDelivered = 3, // 已送达
    TJPChatMessageStatusRead = 4,      // 已读
    TJPChatMessageStatusFailed = 5,    // 发送失败
};



#endif /* TJPChatMessageDefine_h */
