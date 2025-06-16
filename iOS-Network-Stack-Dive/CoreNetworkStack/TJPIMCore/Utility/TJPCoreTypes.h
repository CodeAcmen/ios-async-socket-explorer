//
//  TJPCoreTypes.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#ifndef TJPCoreTypes_h
#define TJPCoreTypes_h

typedef NS_ENUM(NSUInteger, TJPSessionType) {
    TJPSessionTypeDefault = 0,       // 默认通用会话
    TJPSessionTypeChat = 1,          // 聊天会话
    TJPSessionTypeMedia = 2,         // 媒体传输会话
    TJPSessionTypeSignaling = 3      // 信令会话
};

// 协议支持的特性定义
typedef enum {
    // 基本消息能力 (必须支持)
    TJP_FEATURE_BASIC = 0x0001,        // 0000 0000 0000 0001
    
    // 加密能力
    TJP_FEATURE_ENCRYPTION = 0x0002,   // 0000 0000 0000 0010
    
    // 压缩能力
    TJP_FEATURE_COMPRESSION = 0x0004,  // 0000 0000 0000 0100
    
    // 已读回执能力
    TJP_FEATURE_READ_RECEIPT = 0x0008, // 0000 0000 0000 1000
    
    // 群聊能力
    TJP_FEATURE_GROUP_CHAT = 0x0010,   // 0000 0000 0001 0000
} TJPFeatureFlag;

// 当前客户端支持的特性组合
// 这里表示支持: 基本消息 + 加密 + 压缩
#define TJP_SUPPORTED_FEATURES (TJP_FEATURE_BASIC | TJP_FEATURE_ENCRYPTION | TJP_FEATURE_COMPRESSION)


typedef NS_ENUM(NSUInteger, TJPTLVTagPolicy) {
    TJPTLVTagPolicyAllowDuplicates,         //允许重复Tag
    TJPTLVTagPolicyRejectDuplicates         //不允许重复Tag
};

typedef NS_ENUM(NSUInteger, TJPTLVParseError) {
    TJPTLVParseErrorNone = 0,
    TJPTLVParseErrorIncompleteTag,              // 数据不足以读取完整Tag（需至少2字节）
    TJPTLVParseErrorIncompleteLength,           // 数据不足以读取完整Length（需至少4字节）
    TJPTLVParseErrorIncompleteValue,            // Value长度不足（声明的Length超过剩余数据长度）
    TJPTLVParseErrorNestedTooDeep,              // 嵌套层级超过maxNestedDepth限制
    TJPTLVParseErrorDuplicateTag,               // 发现重复Tag（当策略为TJPTLVTagPolicyRejectDuplicates时触发）
    TJPTLVParseErrorInvalidNestedTag            // 非法嵌套Tag（未使用保留Tag进行嵌套）
};

typedef NS_ENUM(uint8_t, TJPEncryptType) {
    TJPEncryptTypeNone = 0,
    TJPEncryptTypeCRC32,
    TJPEncryptTypeAES256,
};

typedef NS_ENUM(uint8_t, TJPCompressType) {
    TJPCompressTypeNone = 0,
    TJPCompressTypeZlib,
};


// 内容类型标签枚举
typedef NS_ENUM(uint16_t, TJPContentType) {
    TJPContentTypeText = 0x1001,     // 文本消息
    TJPContentTypeImage = 0x1002,    // 图片消息
    TJPContentTypeAudio = 0x1003,    // 音频消息
    TJPContentTypeVideo = 0x1004,    // 视频消息
    TJPContentTypeFile = 0x1005,     // 文件消息
    TJPContentTypeLocation = 0x1006, // 位置消息
    TJPContentTypeCustom = 0x1007,   // 自定义消息
};

typedef NS_ENUM(uint16_t, TJPMessageType) {
    TJPMessageTypeNormalData = 0,      // 普通数据消息
    TJPMessageTypeHeartbeat = 1,       // 心跳消息
    TJPMessageTypeACK = 2,             // 确认消息
    TJPMessageTypeControl = 3          // 控制消息
};


typedef NS_ENUM(uint8_t, TJPMessageCategory) {
    TJPMessageCategoryNormal = 0,    // 普通消息
    TJPMessageCategoryHeartbeat = 1, // 心跳消息
    TJPMessageCategoryControl = 2,   // 控制消息
    TJPMessageCategoryMedia = 3      // 媒体消息
};


typedef NS_ENUM(NSInteger, TJPDisconnectReason) {
    TJPDisconnectReasonNone,                   // 默认状态
    TJPDisconnectReasonUserInitiated,          // 手动断开连接
    TJPDisconnectReasonNetworkError,           // 网络错误导致断开
    TJPDisconnectReasonHeartbeatTimeout,       // 心跳超时导致断开
    TJPDisconnectReasonIdleTimeout,            // 空闲超时导致断开
    TJPDisconnectReasonConnectionTimeout,      // 连接超时导致断开
    TJPDisconnectReasonSocketError,            // 套接字错误导致断开
    TJPDisconnectReasonAppBackgrounded,        // APP进入后台误导致断开
    TJPDisconnectReasonForceReconnect          // 强制重连导致断开
};

typedef NS_ENUM(NSUInteger, TJPParseState) {
    TJPParseStateHeader  = 1 << 0,      // 解析协议头
    TJPParseStateBody    = 1 << 1,      // 解析协议体
    TJPParseStateError   = 1 << 2       // 解析出错
};

typedef NS_ENUM(NSUInteger, TJPBufferStrategy) {
    TJPBufferStrategyAuto = 0,       //默认自动选择
    TJPBufferStrategyTradition,      //传统NSMutableData缓冲区
    TJPBufferStrategyRingBuffer      //环形缓冲区
};

typedef NS_ENUM(NSUInteger, TJPNetworkQoS) {
    TJPNetworkQoSDefault              = 1 << 0,
    TJPNetworkQoSBackground           = 1 << 1,
    TJPNetworkQoSUserInitiated        = 1 << 2
};

//网络指标收集级别
typedef NS_ENUM(NSInteger, TJPMetricsLevel) {
    TJPMetricsLevelNone = 0,       // 禁用指标收集
    TJPMetricsLevelBasic = 1,      // 基本指标（连接状态、成功率）
    TJPMetricsLevelStandard = 2,   // 标准指标（包括流量统计、心跳检测）
    TJPMetricsLevelDetailed = 3,   // 详细指标（包括每个消息的RTT、重试统计）
    TJPMetricsLevelDebug = 4       // 调试级别（包括所有可能的指标和原始数据）
};


//定义心跳模式
typedef NS_ENUM(NSUInteger, TJPHeartbeatMode) {
    TJPHeartbeatModeForeground,         // 应用在前台
    TJPHeartbeatModeBackground,         // 应用在后台
    TJPHeartbeatModeSuspended,          // 心跳暂停
    TJPHeartbeatModeLowPower            // 低功耗模式
};

//运营商类型定义
typedef NS_ENUM(NSUInteger, TJPCarrierType) {
    TJPCarrierTypeUnknown,              // 未知运营商
    TJPCarrierTypeChinaMobile,          // 中国移动
    TJPCarrierTypeChinaUnicom,          // 中国联通
    TJPCarrierTypeChinaTelecom,         // 中国电信
    TJPCarrierTypeOther,                // 其他运营商
};

//网络类型定义
typedef NS_ENUM(NSUInteger, TJPNetworkType) {
    TJPNetworkTypeUnknown,          //未知网络
    TJPNetworkTypeWiFi,             //WIFI
    TJPNetworkType5G,               //5G
    TJPNetworkType4G,               //4G
    TJPNetworkType3G,               //3G
    TJPNetworkType2G,               //2G
    TJPNetworkTypeNone,             //无网络
};

//网络健康状态
typedef NS_ENUM(NSUInteger, TJPNetworkHealthStatus) {
    TJPNetworkHealthStatusGood,         // 健康心跳
    TJPNetworkHealthStatusFair,         // 一般心跳
    TJPNetworkHealthStatusPoor,         // 心跳较差
    TJPNetworkHealthStatusCritical      // 心跳严重问题
};

//应用状态类型
typedef NS_ENUM(NSUInteger, TJPAppState) {
    TJPAppStateActive,            // 应用激活状态（前台运行）
    TJPAppStateInactive,          // 应用非激活状态,挂起状态（如接到电话）
    TJPAppStateBackground,        // 应用后台状态
    TJPAppStateTerminated         // 应用终止状态
};

//心跳策略类型
typedef NS_ENUM(NSUInteger, TJPHeartbeatStrategy) {
    TJPHeartbeatStrategyBalanced,       // 平衡策略（默认策略）
    TJPHeartbeatStrategyAggressive,     // 激进策略（较短间隔，适用于重要连接）
    TJPHeartbeatStrategyConservative,   // 保守策略（较长间隔，省电模式）
    TJPHeartbeatStrategyCustom          // 自定义策略 提供自定义接口
};

//心跳状态变更事件类型
typedef NS_ENUM(NSUInteger, TJPHeartbeatStateEvent) {
    TJPHeartbeatStateEventStarted,          // 心跳启动
    TJPHeartbeatStateEventStopped,          // 心跳停止
    TJPHeartbeatStateEventPaused,           // 心跳暂停
    TJPHeartbeatStateEventResumed,          // 心跳恢复
    TJPHeartbeatStateEventModeChanged,      // 心跳模式变更
    TJPHeartbeatStateEventIntervalChanged   // 心跳间隔变更
};



//基于V2的协议头扩充完善
#pragma pack(push, 1)
typedef struct {
    uint32_t magic;                 //魔数 0xDECAFBAD         4字节
    uint8_t version_major;          //协议主版本               1字节
    uint8_t version_minor;          //协议次版本               1字节
    uint16_t msgType;               //消息类型                 2字节
    uint32_t sequence;              //序列号                   4字节
    uint32_t timestamp;             //时间戳 (秒级，防重放攻击)   4字节
    TJPEncryptType encrypt_type;    //加密类型                 1字节
    TJPCompressType compress_type;  //压缩类型                 1字节
    uint16_t session_id;            //会话ID                  2字节
    uint32_t bodyLength;            //Body长度(网络字节序)       4字节
    uint32_t checksum;              //CRC32                   4字节
} TJPFinalAdavancedHeader;
#pragma pack(pop)

static const uint32_t kProtocolMagic = 0xDECAFBAD;

static const uint8_t kProtocolVersionMajor = 1;
static const uint8_t kProtocolVersionMinor = 0;



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
extern TJPConnectEvent const TJPConnectEventConnectFailure;
extern TJPConnectEvent const TJPConnectEventNetworkError;
extern TJPConnectEvent const TJPConnectEventDisconnect;
extern TJPConnectEvent const TJPConnectEventDisconnectComplete;
extern TJPConnectEvent const TJPConnectEventForceDisconnect;       
extern TJPConnectEvent const TJPConnectEventReconnect; 




#endif /* TJPCoreTypes_h */
