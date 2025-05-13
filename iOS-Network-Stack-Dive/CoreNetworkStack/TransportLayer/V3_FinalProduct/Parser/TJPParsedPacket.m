//
//  TJPParsedPacket.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/22.
//

#import "TJPParsedPacket.h"
#import "TJPNetworkDefine.h"

static const uint16_t kTLVReservedNestedTag = 0xFFFF;

@implementation TJPParsedPacket 

+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header payload:(NSData *)payload policy:(TJPTLVTagPolicy)policy maxNestedDepth:(NSUInteger)maxDepth error:(NSError **)error {
    TJPParsedPacket *packet = [[TJPParsedPacket alloc] init];
    packet.header = header;
    packet.payload = payload;
    packet.tagPolicy = policy;
    
    NSError *parseError = nil;
    // 新增TLV解析
    packet.tlvEntries = [self parseTLVFromData:payload policy:policy maxNestedDepth:maxDepth currentDepth:0 error:&parseError];

    if (parseError) {
        if (error) *error = parseError;
        return nil;
    }
    
    packet.messageType = ntohs(header.msgType);  // 需要用ntohs反转消息类型字节序
    packet.sequence = ntohl(header.sequence);    // 使用ntohl转换序列号为主机字节序
    return packet;
}

+ (instancetype)packetWithHeader:(TJPFinalAdavancedHeader)header {
    TJPParsedPacket *packet = [[TJPParsedPacket alloc] init];
    packet.header = header;
    packet.messageType = ntohs(header.msgType);  // 需要用ntohs反转消息类型字节序
    packet.sequence = ntohl(header.sequence);    // 使用ntohl转换序列号为主机字节序
    return packet;
}

// TLV解析核心逻辑
+ (NSDictionary *)parseTLVFromData:(NSData *)data policy:(TJPTLVTagPolicy)policy maxNestedDepth:(NSUInteger)maxDepth currentDepth:(NSUInteger)currentDepth error:(NSError **)error {
    if (currentDepth > maxDepth) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"嵌套深度超过限制:%lu", maxDepth];
            *error = [NSError errorWithDomain:@"TLVError" code:TJPTLVParseErrorNestedTooDeep userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }
    
    NSMutableDictionary *tlvDict = [NSMutableDictionary dictionary];
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger offset = 0;
    
    while (offset < length) {
        //解析Tag
        if (offset + 2 > length) {
            TJPLOG_ERROR(@"TLV解析失败：Tag不完整 (offset=%lu, total=%lu)", offset, length);
            if (error) {
                *error = [NSError errorWithDomain:@"TLVError" code:TJPTLVParseErrorIncompleteTag userInfo:nil];
            }
            return nil;
        }
        
        uint16_t tag = CFSwapInt16BigToHost(*(uint16_t *)(bytes + offset));
        offset += 2;
        
        //解析Length
        if (offset + 4 > length) {
            TJPLOG_ERROR(@"TLV解析失败：Length不完整 (offset=%lu)", offset);
            if (error) {
                *error = [NSError errorWithDomain:@"TLVError" code:TJPTLVParseErrorIncompleteTag userInfo:nil];
            }
            return nil;
        }
        
        uint32_t valueLen = CFSwapInt32BigToHost(*(uint32_t *)(bytes + offset));
        offset += 4;
        
        //解析Value
        if (offset + valueLen > length) {
            TJPLOG_ERROR(@"TLV解析失败：Value长度越界 (声明长度=%u, 剩余长度=%lu)", valueLen, (length - offset));
            if (error) {
                *error = [NSError errorWithDomain:@"TLVError" code:TJPTLVParseErrorIncompleteValue userInfo:nil];
            }
            return nil;
        }
        
        NSData *valueData = [NSData dataWithBytes:bytes + offset length:valueLen];
        offset += valueLen;
        
        //查重Tag
        if (policy == TJPTLVTagPolicyRejectDuplicates && tlvDict[@(tag)]) {
            NSString *msg = [NSString stringWithFormat:@"重复Tag:0x%04X", tag];
            TJPLOG_ERROR(@"%@", msg);
            if (error) {
                *error = [NSError errorWithDomain:@"TLVError" code:TJPTLVParseErrorDuplicateTag userInfo:@{NSLocalizedDescriptionKey: msg}];
            }
            return nil;
        }
        
        //处理嵌套TLV
        if (tag == kTLVReservedNestedTag) {
            NSError *nestedError = nil;
            //递归处理嵌套
            NSDictionary *nested = [self parseTLVFromData:valueData policy:policy maxNestedDepth:maxDepth currentDepth:currentDepth + 1 error:&nestedError];
            
            if (nestedError) {
                if (error) *error = nestedError;
                return nil;
            }
            tlvDict[@(tag)] = nested;
            
        }else {
            tlvDict[@(tag)] = valueData;
        }
    }

    return [tlvDict copy];

}


@end
