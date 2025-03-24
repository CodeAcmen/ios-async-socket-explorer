//
//  TJPMessageParser.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/21.
//

#import "TJPMessageParser.h"
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
        [self parseHeader];
        _state = TJPParseStateBody;
    }
    if (_state == TJPParseStateBody) {
        return [self parseBody];
    }
    return nil;
}

- (void)parseHeader {
    [_buffer getBytes:&_currentHeader length:sizeof(TJPFinalAdavancedHeader)];
    [_buffer replaceBytesInRange:NSMakeRange(0, sizeof(TJPFinalAdavancedHeader)) withBytes:NULL length:0];
    
    //魔数校验失败
    if (ntohl(_currentHeader.magic != kProtocolMagic)) {
        _state = TJPParseStateError;
    }
}

- (TJPParsedPacket *)parseBody {
    uint32_t bodyLength = ntohl(_currentHeader.bodyLength);
    if (_buffer.length < bodyLength) return nil;
    
    NSData *payload = [_buffer subdataWithRange:NSMakeRange(0, bodyLength)];
    [_buffer replaceBytesInRange:NSMakeRange(0, bodyLength) withBytes:NULL length:0];
    
    TJPParsedPacket *packet = [TJPParsedPacket packetWithHeader:_currentHeader payload:payload];
    _state = TJPParseStateHeader;
    return packet;
    
}

- (void)reset {
    [_buffer setLength:0];
    _currentHeader = (TJPFinalAdavancedHeader){0};
}

@end
