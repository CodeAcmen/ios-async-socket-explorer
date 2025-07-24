//
//  TJPDefaultLoadingAnimation.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//

#import "TJPDefaultLoadingAnimation.h"

@implementation TJPDefaultLoadingAnimation

- (UIView *)customLoadingView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 50)];
    container.backgroundColor = [UIColor clearColor];

    UIImageView *loadingImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"img_default_loading"]];
    loadingImage.frame = CGRectMake(0, 0, 40, 40);
    
    loadingImage.center = CGPointMake(CGRectGetMidX(container.bounds), CGRectGetMidY(container.bounds));
    
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.toValue = @(M_PI * 2);
    rotation.duration = 1.0;
    rotation.repeatCount = MAXFLOAT;
    rotation.removedOnCompletion = NO;

    [loadingImage.layer addAnimation:rotation forKey:@"rotate"];
    [container addSubview:loadingImage];

    return container;
}


@end
