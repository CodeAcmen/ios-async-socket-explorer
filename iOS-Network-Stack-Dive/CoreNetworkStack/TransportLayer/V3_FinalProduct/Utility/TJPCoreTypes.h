//
//  TJPCoreTypes.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#ifndef TJPCoreTypes_h
#define TJPCoreTypes_h


typedef NS_ENUM(uint16_t, TJPMessageType) {
    TJPMessageTypeNormalData    = 1 << 0,       //普通数据消息
    TJPMessageTypeHeartbeat     = 1 << 1,       //心跳消息
    TJPMessageTypeACK           = 1 << 2,       //确认消息
    TJPMessageTypeControl       = 1 << 3        //控制消息
};


typedef NS_ENUM(NSInteger, TJPDisconnectReason){
    TJPDisconnectReasonManual           = 1 << 0,  // 手动断开连接
    TJPDisconnectReasonNetworkError     = 1 << 1,  // 网络错误导致断开
    TJPDisconnectReasonHeartbeatTimeout = 1 << 2   // 心跳超时导致断开
};

typedef NS_ENUM(NSUInteger, TJPParseState) {
    TJPParseStateHeader  = 1 << 0,      //解析协议头
    TJPParseStateBody    = 1 << 1,      //解析协议体
    TJPParseStateError   = 1 << 2       //解析出错
};

typedef NS_ENUM(NSUInteger, TJPNetworkQoS) {
    TJPNetworkQoSDefault              = 1 << 0,
    TJPNetworkQoSBackground           = 1 << 1,
    TJPNetworkQoSUserInitiated        = 1 << 2
};



//基于V2的协议头扩充完善
#pragma pack(push, 1)
typedef struct {
    uint32_t magic;                 //魔数 0xDECAFBAD     4字节
    uint8_t version_major;          //协议主版本(大端)      1字节
    uint8_t version_minor;          //协议次版本           1字节
    uint16_t msgType;               //消息类型             2字节
    uint32_t sequence;              //序列号               4字节
    uint32_t bodyLength;            //Body长度(网络字节序)  4字节
    uint32_t checksum;              //CRC32               4字节
} TJPFinalAdavancedHeader;
#pragma pack(pop)

static const uint32_t kProtocolMagic = 0xDECAFBAD;

static const uint8_t kProtocolVersionMajor = 1;
static const uint8_t kProtocolVersionMinor = 0;



//typedef NS_ENUM(NSUInteger, TJPConnecationState) {
//    TJPConnecationStateDisconnected = 1 << 0,  // 连接已断开
//    TJPConnecationStateConnecting   = 1 << 1,  // 正在建立连接
//    TJPConnecationStateConnected    = 1 << 2   // 已成功连接
//};
//定义状态和事件
typedef NSString * TJPConnectState NS_STRING_ENUM;
typedef NSString * TJPConnectEvent NS_STRING_ENUM;

//状态
extern TJPConnectState const TJPConnectStateDisconnected;   //未连接
extern TJPConnectState const TJPConnectStateConnecting;     //正在连接
extern TJPConnectState const TJPConnectStateConnected;      //已连接
extern TJPConnectState const TJPConnectStateDisconnecting;  //正在断开

//事件
extern TJPConnectEvent const TJPConnectEventConnect;
extern TJPConnectEvent const TJPConnectEventConnectSuccess;
extern TJPConnectEvent const TJPConnectEventConnectFailed;
extern TJPConnectEvent const TJPConnectEventDisconnect;
extern TJPConnectEvent const TJPConnectEventDisconnectComplete;




#endif /* TJPCoreTypes_h */
