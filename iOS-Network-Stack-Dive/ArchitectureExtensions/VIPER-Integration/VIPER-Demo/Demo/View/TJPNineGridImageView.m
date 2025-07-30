//
//  TJPNineGridImageView.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/30.
//

#import "TJPNineGridImageView.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@implementation TJPNineGridImageView

- (void)setImageUrls:(NSArray<NSString *> *)imageUrls {
    _imageUrls = imageUrls;
    
    // 清除旧的图片视图
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    
    if (imageUrls.count == 0) {
        return;
    }
    
    [self layoutImageViews];
}

- (void)layoutImageViews {
    CGFloat itemWidth = 80;
    CGFloat itemSpacing = 5;
    
    for (NSInteger i = 0; i < self.imageUrls.count; i++) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = 4;
        imageView.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:imageView];
        
        // 计算九宫格位置
        NSInteger row = i / 3;
        NSInteger col = i % 3;
        
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).offset(col * (itemWidth + itemSpacing));
            make.top.equalTo(self).offset(row * (itemWidth + itemSpacing));
            make.width.height.equalTo(@(itemWidth));
        }];
        
        // 加载图片
        [imageView sd_setImageWithURL:[NSURL URLWithString:self.imageUrls[i]]];
        
        // 添加点击手势
        imageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)];
        imageView.tag = i;
        [imageView addGestureRecognizer:tap];
    }
}

- (void)imageViewTapped:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag;
    NSLog(@"点击了第 %ld 张图片", (long)index);
    // 现图片浏览器功能
}

@end
