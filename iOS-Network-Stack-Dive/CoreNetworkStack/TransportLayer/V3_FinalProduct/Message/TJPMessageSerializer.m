//
//  TJPMessageSerializer.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import "TJPMessageSerializer.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TJPNetworkDefine.h"
#import "UIImage+TJPImageOrientation.h"

@implementation TJPMessageSerializer

+ (NSData *)serializeText:(NSString *)text tag:(uint16_t)tag {
    if (!text.length && text == nil) {
        TJPLOG_ERROR(@"图片序列化失败：image参数为nil");
        return nil;
    }
    NSData *textData = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    //构建TLV结构
    return [self buildTLVWithTag:tag value:textData];
}



+ (NSData *)serializeImage:(UIImage *)image tag:(uint16_t)tag {
    //参数校验
    NSCParameterAssert(image && [image isKindOfClass:[UIImage class]]);
    if (!image) {
        TJPLOG_ERROR(@"图片序列化失败：image参数为nil");
        return nil;
    }
    
    //图片预处理 调整尺寸和方向
    UIImage *processedImage = [self _processImageBeforeEncoding:image];
    
    // 3. 智能选择编码格式
    NSData *imageData = [self _encodeImageData:processedImage];
    if (!imageData) {
        TJPLOG_ERROR(@"图片编码失败：无法生成有效数据");
        return nil;
    }

    // 4. 构建TLV结构（复用基础方法）
    return [self buildTLVWithTag:tag value:imageData];
}


#pragma mark - Private Method
+ (UIImage *)_processImageBeforeEncoding:(UIImage *)srcImage {
    //最大允许尺寸
    static const CGSize kMaxSize = {1024, 1024};
    
    //方向修正 (解决图片拍摄旋转问题)
    UIImage *fixedImage = [srcImage fixOrientation];
    
    // 尺寸缩放检查
    if (fixedImage.size.width <= kMaxSize.width &&
        fixedImage.size.height <= kMaxSize.height) {
        return fixedImage;
    }
    
    // 等比例缩放
    CGFloat ratio = MIN(kMaxSize.width / fixedImage.size.width, kMaxSize.height / fixedImage.size.height);
    
    //处理后的尺寸
    CGSize newSize = CGSizeMake(floor(fixedImage.size.width * ratio), floor(fixedImage.size.height * ratio));
    
    UIGraphicsBeginImageContextWithOptions(newSize, YES, [UIScreen mainScreen].scale);
    [fixedImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage ?: fixedImage;
    
}

+ (NSData *)_encodeImageData:(UIImage *)image {
    // 格式选择策略
    BOOL hasAlpha = [self _imageHasAlphaChannel:image];
    
    // 编码参数配置
    NSDictionary *options = @{
        // 透明图用PNG，不透明用JPEG
        (id)kCGImageDestinationLossyCompressionQuality: @(hasAlpha ? 1.0 : 0.85)
    };
    
    // 自动选择最佳格式
    CFStringRef type = hasAlpha ? (CFStringRef)@"public.png" : (CFStringRef)@"public.jpeg";

    // 编码为二进制数据
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, type, 1, NULL);
    
    if (!dest) return nil;
    
    CGImageDestinationAddImage(dest, image.CGImage, (__bridge CFDictionaryRef)options);
    BOOL success = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    
    return success ? [data copy] : nil;
}





#pragma mark - Common Method
+ (NSData *)buildTLVWithTag:(uint16_t)tag value:(NSData *)value {
    //字节序转换  (主机序→网络序)
    uint16_t netTag = CFSwapInt16HostToBig(tag);  // 2字节Tag转大端
    uint32_t netLength = CFSwapInt32HostToBig((uint32_t)value.length); // 4字节Length转大端
    
    //单次内存分配 避免频繁扩容 (Tag2 + Length4 + valueN)
    NSUInteger totalLength = 2 + 4 + value.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:totalLength];
    
    //直接操作底层缓冲区（零拷贝）
    [data setLength:totalLength];
    uint8_t *buffer = [data mutableBytes];
    
    memcpy(buffer, &netTag, 2);
    memcpy(buffer + 2, &netLength, 4);
    memcpy(buffer + 6, value.bytes, value.length);

    return [data copy];
}

/**
 * 检测图片是否包含透明通道
 */
+ (BOOL)_imageHasAlphaChannel:(UIImage *)image {
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image.CGImage);
    return (alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}

@end
