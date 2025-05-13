//
//  TJPParsedPacket.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//  用于表示解析后的协议包

#import <Foundation/Foundation.h>
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN


@interface TJPParsedPacket : NSObject
/// 消息类型
@property (nonatomic, assign) TJPMessageType messageType;
/// 序列号
@property (nonatomic, assign) uint32_t sequence;
/// 消息头
@property (nonatomic, assign) TJPFinalAdavancedHeader header;
/// 消息内容
@property (nonatomic, strong) NSData *payload;
/// TLV解析后的字段（Tag -> Value）
@property (nonatomic, strong) NSDictionary<NSNumber *, id> *tlvEntries; // 支持嵌套存储
/// TLV策略
@property (nonatomic, assign) TJPTLVTagPolicy tagPolicy;


+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header;

+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header payload:(NSData *)payload policy:(TJPTLVTagPolicy)policy maxNestedDepth:(NSUInteger)maxDepth error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
