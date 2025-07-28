//
//  TJPErrorUtil.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/14.
//

#import <Foundation/Foundation.h>
#import "TJPNetworkErrorDefine.h"
#import "TJPCoreTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPErrorUtil : NSObject

/**
 * 创建标准的网络错误对象
 * @param code 错误代码
 * @param description 错误描述
 * @param userInfo 附加信息 (可选，如果为nil则创建空字典)
 * @return NSError实例
 */
+ (NSError *)errorWithCode:(TJPNetworkError)code description:(NSString *)description userInfo:(NSDictionary *)userInfo;

/**
 * 创建带有失败原因的网络错误对象
 * @param code 错误代码
 * @param description 错误描述
 * @param failureReason 失败原因
 * @return NSError实例
 */
+ (NSError *)errorWithCode:(TJPNetworkError)code description:(NSString *)description failureReason:(NSString *)failureReason;

/**
 * 将TLV解析错误代码转换为网络错误代码
 * @param tlvError TLV解析错误代码
 * @return 对应的网络错误代码
 */
+ (TJPNetworkError)networkErrorFromTLVError:(TJPTLVParseError)tlvError;


@end

NS_ASSUME_NONNULL_END
