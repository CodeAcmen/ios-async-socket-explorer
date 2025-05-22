//
//  TJPTextMessage.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/5/13.
//

#import <Foundation/Foundation.h>
#import "TJPMessageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TJPTextMessage : NSObject <TJPMessageProtocol>

@property (nonatomic, copy) NSString *text;

- (instancetype)initWithText:(NSString *)text;


@end

NS_ASSUME_NONNULL_END
