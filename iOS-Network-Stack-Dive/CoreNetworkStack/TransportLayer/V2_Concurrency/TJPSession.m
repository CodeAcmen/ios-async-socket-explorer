//
//  TJPSession.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/20.
//

#import "TJPSession.h"

@interface TJPSession ()

@end

@implementation TJPSession

- (instancetype)init {
    if (self = [super init]) {
        _parserBuffer = [NSMutableData data];
        _currentHeader = (TJPAdavancedHeader){0};
        _isParsingHeader = YES;
        _parserQueue = dispatch_queue_create("com.tjp.tjpSession.parseQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)resetParser {
    [self.parserBuffer setLength:0];
    _currentHeader = (TJPAdavancedHeader){0};
}


@end
