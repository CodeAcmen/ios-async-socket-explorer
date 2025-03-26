//
//  TJPMessageParser.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageParser.h"
#import "JZNetworkDefine.h"
#import "TJPParsedPacket.h"
#import "TJPCoreTypes.h"

@interface TJPMessageParser () {
    TJPFinalAdavancedHeader _currentHeader;
    NSMutableData *_buffer;
    TJPParseState _state;
}

@end

@implementation TJPMessageParser

- (instancetype)init {
    if (self = [super init]) {
        _buffer = [NSMutableData data];
        _state = TJPParseStateHeader;
    }
    return self;
}


- (void)feedData:(NSData *)data {
    [_buffer appendData:data];
}

- (BOOL)hasCompletePacket {
    if (_state == TJPParseStateHeader) {
        return _buffer.length >= sizeof(TJPFinalAdavancedHeader);
    }else {
        return _buffer.length >= ntohl(_currentHeader.bodyLength);
    }
}

- (TJPParsedPacket *)nextPacket {
    if (_state == TJPParseStateHeader) {
        return [self parseHeaderData];
    }
    if (_state == TJPParseStateBody) {
        return [self parseBodyData];
    }
    return nil;
}

- (TJPParsedPacket *)parseHeaderData {
    if (_buffer.length < sizeof(TJPFinalAdavancedHeader)) {
        TJPLOG_INFO(@"数据长度不够数据头解析");
        return nil;
    }
    TJPFinalAdavancedHeader currentHeader = {0};

    //解析头部
    [_buffer getBytes:&currentHeader length:sizeof(TJPFinalAdavancedHeader)];

    
    //魔数校验失败
    if (ntohl(currentHeader.magic) != kProtocolMagic) {
        TJPLOG_INFO(@"解析头部后魔数校验失败... 请检查");
        _state = TJPParseStateError;
        return nil;
    }
    TJPLOG_INFO(@"解析数据头部成功...魔数校验成功!");
    _currentHeader = currentHeader;
    //移除已处理的Header数据
    [_buffer replaceBytesInRange:NSMakeRange(0, sizeof(TJPFinalAdavancedHeader)) withBytes:NULL length:0];
    
    TJPParsedPacket *header = [TJPParsedPacket packetWithHeader:_currentHeader];
    TJPLOG_INFO(@"解析序列号:%u 的头部成功", ntohl(_currentHeader.sequence));
    _state = TJPParseStateBody;
    
    return header;
}

- (TJPParsedPacket *)parseBodyData {
    uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
    if (_buffer.length < bodyLength) {
        TJPLOG_INFO(@"数据长度不够内容解析,等待更多数据...");
        return nil;
    }
    
    NSData *payload = [_buffer subdataWithRange:NSMakeRange(0, bodyLength)];
    [_buffer replaceBytesInRange:NSMakeRange(0, bodyLength) withBytes:NULL length:0];
    
    TJPParsedPacket *body = [TJPParsedPacket packetWithHeader:_currentHeader payload:payload];
    TJPLOG_INFO(@"解析序列号:%u 的内容成功", ntohl(_currentHeader.sequence));

    _state = TJPParseStateHeader;
    return body;
}

- (void)reset {
    [_buffer setLength:0];
    _currentHeader = (TJPFinalAdavancedHeader){0};
}



#pragma mark - 单元测试
- (NSMutableData *)buffer {
    return _buffer;
}


- (TJPFinalAdavancedHeader)currentHeader {
    return _currentHeader;
}
@end
