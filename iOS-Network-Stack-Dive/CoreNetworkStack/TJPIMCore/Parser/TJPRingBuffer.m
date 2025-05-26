//
//  TJPRingBuffer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/26.
//

#import "TJPRingBuffer.h"
#import "TJPNetworkDefine.h"

@interface TJPRingBuffer () {
    char *_buffer;
    NSUInteger _capacity;
    NSUInteger _readIndex;
    NSUInteger _writeIndex;
    NSUInteger _usedSize;
    dispatch_queue_t _accessQueue;
}

@end

@implementation TJPRingBuffer
#pragma mark - Lifecycle
- (instancetype)initWithCapacity:(NSUInteger)capacity {
    if (self = [super init]) {
        // 边界判断
        if (capacity == 0  || capacity > TJPMAX_BUFFER_SIZE) {
            TJPLOG_ERROR(@"无效的缓冲区容量: %lu", capacity);
            return nil;
        }
        
        _capacity = capacity;
        // 开辟内存空间
        _buffer = malloc(capacity);
        if (!_buffer) {
            TJPLOG_ERROR(@"环形缓冲区内存分配失败，容量: %lu", capacity);
            return nil;
        }
        
        _readIndex = 0;
        _writeIndex = 0;
        _usedSize = 0;
        
        _accessQueue = dispatch_queue_create("com.tjp.ringBuffer.accessQueue", DISPATCH_QUEUE_SERIAL);
        
        TJPLOG_INFO(@"环形缓冲区初始化成功，容量: %lu bytes", capacity);
        
    }
    return self;
}


- (void)dealloc {
    if (_buffer) {
        free(_buffer);
        _buffer = NULL;
    }
}

#pragma mark - Public Method
- (NSUInteger)writeData:(NSData *)data {
    if (!data || data.length == 0) {
        return 0;;
    }
    return [self writeBytes:data.bytes length:data.length];
    
}

- (NSUInteger)writeBytes:(const void *)bytes length:(NSUInteger)length {
    if (!bytes || length == 0) {
        return 0;
    }
    
    __block NSUInteger writtenBytes = 0;
    dispatch_sync(_accessQueue, ^{
        writtenBytes = [self _unsafeWriteBytes:bytes length:length];
    });
    return writtenBytes;
}

- (NSUInteger)_unsafeWriteBytes:(const void*)bytes length:(NSUInteger)length {
    //计算可写入的字节数
    NSUInteger availableSpace = _capacity - _usedSize;
    NSUInteger bytesToWrite = MIN(length, availableSpace);
    
    if (bytesToWrite == 0) {
        TJPLOG_WARN(@"环形缓冲区空间不足，无法写入数据");
        return 0;
    }
    const char *sourceBytes = (const char *)bytes;
    
    //计算写入到缓冲区末尾的字节数
    NSUInteger bytesToEnd = _capacity - _writeIndex;
    
    if (bytesToWrite <= bytesToEnd) {
        //数据可以连续写入
        memcpy(_buffer + _writeIndex, sourceBytes, bytesToWrite);
    }else {
        //到尾部了需要拼接头部写入  环绕
        memcpy(_buffer + _writeIndex, sourceBytes, bytesToEnd);
        //写头部
        memcpy(_buffer, sourceBytes + bytesToEnd, bytesToWrite - bytesToEnd);
    }
    
    //更新写指针
    _writeIndex = (_writeIndex + bytesToWrite) % _capacity;
    _usedSize += bytesToWrite;
    
    return bytesToWrite;
}

- (NSData *)readData:(NSUInteger)length {
    if (length == 0) {
        return [NSData data];
    }
    
    __block NSData *result = nil;
    dispatch_sync(_accessQueue, ^{
        if (self->_usedSize < length) {
            return;
        }
        char *tempBuffer = malloc(length);
        if (!tempBuffer) {
            TJPLOG_ERROR(@"临时缓冲区分配失败");
            return;
        }
        NSUInteger readBytes = [self _unsafeReadBytes:tempBuffer length:length];
        if (readBytes == length) {
            result = [NSData dataWithBytes:tempBuffer length:length];
        }
        free(tempBuffer);
    });
    return result;
    
}

- (NSUInteger)readBytes:(void *)buffer length:(NSUInteger)length {
    if (!buffer || length == 0) {
        return 0;
    }
    
    __block NSUInteger readBytes = 0;
    dispatch_sync(_accessQueue, ^{
        readBytes = [self _unsafeReadBytes:buffer length:length];
    });
    
    return readBytes;
}

- (NSUInteger)_unsafeReadBytes:(void*)buffer length:(NSUInteger)length {
    NSUInteger bytesToRead = MIN(length, _usedSize);
    
    if (bytesToRead == 0) {
        return 0;
    }
    
    char *destBuffer = (char *)buffer;
    
    //计算从读指针到缓冲区末尾的字节数
    NSUInteger bytesToEnd = _capacity - _readIndex;
    
    if (bytesToRead <= bytesToEnd) {
        //数据可以连续读取
        memcpy(destBuffer, _buffer + _readIndex, bytesToRead);
    }else {
        //需要环绕读取
        memcpy(destBuffer, _buffer + _readIndex, bytesToEnd);
        memcpy(destBuffer + bytesToEnd, _buffer, bytesToRead - bytesToEnd);
    }
    
    //更新读指针大小
    _readIndex = (_readIndex + bytesToRead) % _capacity;
    _usedSize -= bytesToRead;
    
    return bytesToRead;
}

- (NSData *)peekData:(NSUInteger)length {
    if (length == 0) {
        return [NSData data];
    }
    
    __block NSData *result = nil;
    dispatch_sync(_accessQueue, ^{
        if (self->_usedSize < length) {
            return;
        }
        
        char *tempBuffer = malloc(length);
        if (!tempBuffer) {
            TJPLOG_ERROR(@"临时缓冲区分配失败");
            return;
        }
        
        NSUInteger peekBytes = [self _unsafePeekBytes:tempBuffer length:length];
        if (peekBytes == length) {
            result = [NSData dataWithBytes:tempBuffer length:length];
        }
        free(tempBuffer);
    });
    
    return result;
}

- (NSUInteger)peekBytes:(void *)buffer length:(NSUInteger)length {
    if (!buffer || length == 0) {
        return 0;
    }
    
    __block NSUInteger peekBytes = 0;
    dispatch_sync(_accessQueue, ^{
        peekBytes = [self _unsafePeekBytes:buffer length:length];
    });
    
    return peekBytes;
}

- (NSUInteger)_unsafePeekBytes:(void *)buffer length:(NSUInteger)length {
    NSUInteger bytesToPeek = MIN(length, _usedSize);
    
    if (bytesToPeek == 0) {
        return 0;
    }
    
    char *destBuffer = (char *)buffer;
    NSUInteger tempReadIndex = _readIndex;
    
    //计算从读指针到缓冲区末尾的字节数
    NSUInteger bytesToEnd = _capacity - tempReadIndex;
    
    if (bytesToPeek <= bytesToEnd) {
        //数据可以连续读取
        memcpy(destBuffer, _buffer + tempReadIndex, bytesToPeek);
    }else {
        //分段读取 环绕
        memcpy(destBuffer, _buffer + tempReadIndex, bytesToEnd);
        memcpy(destBuffer + bytesToEnd, _buffer, bytesToPeek - bytesToEnd);
    }
    
    // peek时操作部更新读指针和大小
    return bytesToPeek;

}

- (NSUInteger)skipBytes:(NSUInteger)length {
    __block NSUInteger skippedBytes = 0;
    dispatch_sync(_accessQueue, ^{
        NSUInteger bytesToSkip = MIN(length, self->_usedSize);
        self->_readIndex = (self->_readIndex + bytesToSkip) % self->_capacity;
        self->_usedSize -= bytesToSkip;
        skippedBytes = bytesToSkip;
    });
    return skippedBytes;
}

- (void)reset {
    dispatch_sync(_accessQueue, ^{
        self->_readIndex = 0;
        self->_writeIndex = 0;
        self->_usedSize = 0;
    });
    TJPLOG_INFO(@"环形缓冲区已重置");
}

- (BOOL)hasAvailableData:(NSUInteger)length {
    return self.usedSize >= length;
}

- (CGFloat)usageRatio {
    return (CGFloat)self.usedSize / (CGFloat)_capacity;
}

#pragma mark - Debug

- (NSString *)description {
    return [NSString stringWithFormat:@"<TJPRingBuffer: capacity=%lu, size=%lu, readIndex=%lu, writeIndex=%lu, usage=%.1f%%>",
            _capacity, self.usedSize, self.readIndex, self.writeIndex, self.usageRatio * 100];
}

#pragma mark - Getter Method
- (NSUInteger)capacity {
    return _capacity;
}

- (NSUInteger)usedSize {
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = self->_usedSize;
    });
    return result;
}

- (NSUInteger)availableSpace {
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = self->_capacity - self->_usedSize;
    });
    return result;
}

- (NSUInteger)readIndex {
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = self->_readIndex;
    });
    return result;
}

- (NSUInteger)writeIndex {
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = self->_writeIndex;
    });
    return result;
}



@end
