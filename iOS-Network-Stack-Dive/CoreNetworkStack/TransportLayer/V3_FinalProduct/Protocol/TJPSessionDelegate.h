//
//  TJPSessionDelegate.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//  整合所有代理

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocation.h>
#import "TJPCoreTypes.h"
#import "TJPSessionProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TJPSessionDelegate <NSObject>

@optional

// 通知协调器处理重连
- (void)sessionNeedsReconnect:(id<TJPSessionProtocol>)session;

// === 状态回调 ===
// 连接状态变化
- (void)session:(id<TJPSessionProtocol>)session didChangeState:(TJPConnectState)state;
// 连接断开
- (void)session:(id<TJPSessionProtocol>)session didDisconnectWithReason:(TJPDisconnectReason)reason;
// 连接失败
- (void)session:(id<TJPSessionProtocol>)session didFailWithError:(NSError *)error;

// === 内容回调 ===
// 接收文本
- (void)session:(id<TJPSessionProtocol>)session didReceiveText:(NSString *)text;
// 接收图片
- (void)session:(id<TJPSessionProtocol>)session didReceiveImage:(UIImage *)image;
// 接收音频
- (void)session:(id<TJPSessionProtocol>)session didReceiveAudio:(NSData *)audioData;
// 接收视频
- (void)session:(id<TJPSessionProtocol>)session didReceiveVideo:(NSData *)videoData;
// 接收文件
- (void)session:(id<TJPSessionProtocol>)session didReceiveFile:(NSData *)fileData filename:(NSString *)filename;
// 接收位置
- (void)session:(id<TJPSessionProtocol>)session didReceiveLocation:(CLLocation *)location;
// 接收自定义内容
- (void)session:(id<TJPSessionProtocol>)session didReceiveCustomData:(NSData *)data withType:(uint16_t)customType;

// 发送消息失败
- (void)session:(id<TJPSessionProtocol>)session didFailToSendMessageWithSequence:(uint32_t)sequence error:(NSError *)error;

// === 原始数据回调（高级用户） ===
// 接收原始数据
- (void)session:(id<TJPSessionProtocol>)session didReceiveRawData:(NSData *)data;


@end

NS_ASSUME_NONNULL_END
