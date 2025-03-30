//
//  TJPLoggerViewController.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJPLoggerViewController : UIViewController

- (NSString *)processData:(NSData *)data count:(int)count;
- (void)testMethod;
- (NSString *)greeting:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
