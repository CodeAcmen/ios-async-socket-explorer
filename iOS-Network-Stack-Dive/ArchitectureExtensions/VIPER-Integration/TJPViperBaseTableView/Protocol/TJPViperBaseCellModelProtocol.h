//
//  TJPViperBaseCellModelProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/29.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, JZNavigationType) {
    JZNavigationTypePush    = 1 << 0,  // 普通Push跳转
    JZNavigationTypePresent = 1 << 1,  // 弹出跳转
    JZNavigationTypeModal   = 1 << 2,  // Modal跳转
    JZNavigationTypeCustom  = 1 << 3   // 自定义跳转
};

@protocol TJPViperBaseCellModelProtocol <NSObject>

@property (nonatomic, strong) RACCommand<id<TJPViperBaseCellModelProtocol>, NSObject*>* selectedCommand;


// 返回要跳转的类型
- (JZNavigationType)navigationTypeForModel;

- (NSString *)cellName;
- (CGFloat)cellHeight;

@end

NS_ASSUME_NONNULL_END
