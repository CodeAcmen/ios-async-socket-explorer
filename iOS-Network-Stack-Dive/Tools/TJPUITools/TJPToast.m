//
//  TJPToast.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/31.
//

#import "TJPToast.h"
#import "TJPNetworkDefine.h"

static int changeCount;


@interface TJPToast ()

@property (nonatomic, strong) TJPToastLabel *toastLabel;
@property (nonatomic, strong) NSTimer *countTimer;


@end

@implementation TJPToast

+ (instancetype)shareInstance
{
    static TJPToast *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[TJPToast alloc] init];
    });
    return singleton;
}

/**
 *  初始化方法
 *
 *  @return 自身
 */
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.toastLabel = [[TJPToastLabel alloc]init];

        self.countTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(changeTime) userInfo:nil repeats:YES];
        self.countTimer.fireDate = [NSDate distantFuture];//关闭定时器
    }
    return self;
}

/**
 *  弹出并显示Toast
 *
 *  @param title  显示的文本内容
 *  @param duration 显示时间
 */
+ (void)show:(NSString *)title duration:(CGFloat)duration {
    if ([title length] == 0) {
        return;
    }
    TJPToast *instance = [self shareInstance];
    [instance.toastLabel setMessageText:title];
    [[[UIApplication sharedApplication]keyWindow] addSubview:instance.toastLabel];

    instance.toastLabel.alpha = 0.8;
    instance.countTimer.fireDate = [NSDate distantPast];//开启定时器
    changeCount = duration;
}

+ (void)show:(NSString *)title duration:(CGFloat)duration controller:(UIViewController *)controller {
    if ([title length] == 0) {
        return;
    }
    TJPToast *instance = [self shareInstance];
    [instance.toastLabel setMessageText:title];
    [controller.view.window addSubview:instance.toastLabel];

    instance.toastLabel.alpha = 0.8;
    instance.countTimer.fireDate = [NSDate distantPast];//开启定时器
    changeCount = duration;
}


/**
 *  定时器回调方法
 */
- (void)changeTime
{
    //NSLog(@"时间：%d",changeCount);
    if(changeCount-- <= 0){
        self.countTimer.fireDate = [NSDate distantFuture];//关闭定时器
        [UIView animateWithDuration:0.2f animations:^{
            self.toastLabel.alpha = 0;
        } completion:^(BOOL finished) {
            [self.toastLabel removeFromSuperview];
        }];
    }
}


@end


@implementation TJPToastLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.layer.cornerRadius = 8;
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor blackColor];
        self.numberOfLines = 0;
        self.textAlignment = NSTextAlignmentCenter;
        self.textColor = [UIColor whiteColor];
        self.font = [UIFont systemFontOfSize:15];
    }
    return self;
}

/**
 *  设置显示的文字
 *
 *  @param text 文字文本
 */
- (void)setMessageText:(NSString *)text{
    [self setText:text];

    CGRect rect = [self.text boundingRectWithSize:CGSizeMake(TJPSCREEN_WIDTH-20, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:self.font} context:nil];

    CGFloat width = rect.size.width + 20;
    CGFloat height = rect.size.height + 20;
    CGFloat x = (TJPSCREEN_WIDTH-width)/2;
    CGFloat y = (TJPSCREEN_HEIGHT-height)/2+30;

    self.frame = CGRectMake(x, y, width, height);
}

@end
