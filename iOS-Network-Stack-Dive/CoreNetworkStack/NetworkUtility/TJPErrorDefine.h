//
//  TJPErrorDefine.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/10.
//


#ifndef TJPErrorUtil_h
#define TJPErrorUtil_h

#import <Foundation/Foundation.h>

/**
 * 网络错误代码枚举
 * 错误域: "com.tjp.network.error"
 */
typedef NS_ENUM(NSInteger, TJPNetworkError) {
    // 一般错误 (0-999)
    TJPErrorNone                          = 0,    // 无错误
    TJPErrorUnknown                       = 1,    // 未知错误
    TJPErrorTimeout                       = 2,    // 超时
    TJPErrorCancelled                     = 3,    // 操作被取消
    
    // 连接相关错误 (1000-1999)
    TJPErrorConnectionFailed              = 1000, // 连接失败
    TJPErrorConnectionTimeout             = 1001, // 连接超时
    TJPErrorConnectionLost                = 1002, // 连接丢失
    TJPErrorConnectionRefused             = 1003, // 连接被拒绝
    TJPErrorNetworkUnavailable            = 1004, // 网络不可用
    TJPErrorServerUnavailable             = 1005, // 服务器不可用
    TJPErrorTLSHandshakeFailed            = 1006, // TLS握手失败
    
    // 消息传输错误 (2000-2999)
    TJPErrorMessageSendFailed             = 2000, // 消息发送失败
    TJPErrorMessageReceiveFailed          = 2001, // 消息接收失败
    TJPErrorMessageTimeout                = 2002, // 消息超时未收到响应
    TJPErrorMessageTooLarge               = 2003, // 消息体过大
    TJPErrorMessageFormatInvalid          = 2004, // 消息格式无效
    TJPErrorMessageACKMissing             = 2005, // 未收到ACK确认
    TJPErrorMessageRetryExceeded          = 2006, // 超过最大重试次数
    
    // 协议解析错误 (3000-3999)
    TJPErrorProtocolVersionMismatch       = 3000, // 协议版本不匹配
    TJPErrorProtocolMagicInvalid          = 3001, // 魔数无效
    TJPErrorProtocolChecksumMismatch      = 3002, // 校验和不匹配
    TJPErrorProtocolHeaderInvalid         = 3003, // 协议头无效
    TJPErrorProtocolPayloadLengthMismatch = 3004, // 负载长度不匹配
    TJPErrorProtocolUnsupportedEncryption = 3005, // 不支持的加密类型
    TJPErrorProtocolUnsupportedCompression= 3006, // 不支持的压缩类型
    TJPErrorProtocolTimestampInvalid      = 3007, // 时间戳无效
    
    // TLV解析错误 (4000-4999)
    TJPErrorTLVParseError                 = 4000, // TLV解析错误
    TJPErrorTLVIncompleteTag              = 4001, // 不完整的Tag
    TJPErrorTLVIncompleteLength           = 4002, // 不完整的Length
    TJPErrorTLVIncompleteValue            = 4003, // 不完整的Value
    TJPErrorTLVDuplicateTag               = 4004, // 重复的Tag
    TJPErrorTLVNestedTooDeep              = 4005, // 嵌套深度过大
    
    // 安全相关错误 (5000-5999)
    TJPErrorSecurityEncryptionFailed      = 5000, // 加密失败
    TJPErrorSecurityDecryptionFailed      = 5001, // 解密失败
    TJPErrorSecurityUnauthorized          = 5002, // 未授权
    TJPErrorSecurityReplayAttackDetected  = 5003, // 检测到重放攻击
    TJPErrorSecurityInvalidSignature      = 5004, // 签名无效
    
    // 会话相关错误 (6000-6999)
    TJPErrorSessionExpired                = 6000, // 会话过期
    TJPErrorSessionInvalid                = 6001, // 会话无效
    TJPErrorSessionLimitExceeded          = 6002, // 超出会话限制
    TJPErrorSessionHeartbeatTimeout       = 6003, // 心跳超时
    TJPErrorSessionStateError             = 6004, // 会话状态错误
    
    // 业务逻辑错误 (7000-7999)
    TJPErrorBusinessLogicFailed           = 7000, // 业务逻辑失败
    
    // 系统错误 (8000-8999)
    TJPErrorSystemMemoryLow               = 8000, // 系统内存不足
    TJPErrorSystemDiskFull                = 8001, // 磁盘空间不足
    TJPErrorSystemIOFailure               = 8002  // IO操作失败
};

// 错误域常量
FOUNDATION_EXPORT NSString * const TJPNetworkErrorDomain;



#endif /* TJPErrorUtil_h */
