//
//  TJPFPSLabel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/29.
//

#import "TJPFPSLabel.h"
#import <QuartzCore/QuartzCore.h>


@implementation TJPFPSLabel  {
    CADisplayLink *_link;
    NSUInteger _count;
    NSTimeInterval _lastTime;
    UIFont *_font;
    UIFont *_subFont;
    UIColor *_normalColor;
    UIColor *_warnColor;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.layer.cornerRadius = 5;
    self.clipsToBounds = YES;
    self.textAlignment = NSTextAlignmentCenter;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.700];

    _font = [UIFont fontWithName:@"Menlo" size:14];
    if (_font) {
        _subFont = [UIFont fontWithName:@"Menlo" size:4];
    } else {
        _font = [UIFont systemFontOfSize:14];
        _subFont = [UIFont systemFontOfSize:4];
    }

    _normalColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0]; // Green
    _warnColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];   // Red

    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    return self;
}

- (void)dealloc {
    [_link invalidate];
}

- (void)tick:(CADisplayLink *)link {
    if (_lastTime == 0) {
        _lastTime = link.timestamp;
        return;
    }

    _count++;
    NSTimeInterval delta = link.timestamp - _lastTime;
    if (delta < 1) return;

    _lastTime = link.timestamp;
    float fps = _count / delta;
    _count = 0;

    // 更新文本
    NSString *text = [NSString stringWithFormat:@"%d FPS", (int)round(fps)];

    UIColor *color = fps >= 55 ? _normalColor : _warnColor;

    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:text];
    [attrText addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, text.length - 3)];
    [attrText addAttribute:NSFontAttributeName value:_font range:NSMakeRange(0, text.length)];
    self.attributedText = attrText;
}

@end
