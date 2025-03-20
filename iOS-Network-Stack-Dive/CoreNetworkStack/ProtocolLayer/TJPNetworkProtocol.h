//
//  TJPNetworkProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/19.
//  协议头接口

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJPNetworkProtocol <NSObject>

typedef NS_ENUM(uint16_t, TJPMessageType) {
    TJPMessageTypeNormalData = 1,   //普通数据消息
    TJPMessageTypeHeartbeat = 2,    //心跳消息
    TJPMessageTypeACK = 3           //确认消息
};

@end

#pragma pack(push, 1)
typedef struct {
    uint32_t magic;                 //魔数 0xDECAFBAD     4字节
    uint8_t version_major;          //协议主版本(大端)      1字节
    uint8_t version_minor;          //协议次版本           1字节
    uint16_t msgType;               //消息类型             2字节
    uint32_t sequence;              //序列号               4字节
    uint32_t bodyLength;            //Body长度(网络字节序)  4字节
    uint32_t checksum;              //CRC32               4字节
} TJPAdavancedHeader;
#pragma pack(pop)

static const uint32_t kProtocolMagic = 0xDECAFBAD;
/*
 协议版本策略: 语义化版本控制
 主版本变更:必须断开连接并升级
 次版本变更:服务端需支持最近3个次版本
 不定版本:客户端自动适配
 
 平衡效率与可读性后,采用uint8_t分段.总占用2字节
 */
static const uint8_t kProtocolVersionMajor = 1;
static const uint8_t kProtocolVersionMinor = 0;



NS_ASSUME_NONNULL_END
