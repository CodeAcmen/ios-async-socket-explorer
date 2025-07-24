//
//  TJPBaseSectionModel.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//

#import <Foundation/Foundation.h>
#import "TJPBaseSectionModelProtocol.h"


NS_ASSUME_NONNULL_BEGIN
@protocol TJPBaseCellModelProtocol;

@interface TJPBaseSectionModel : NSObject <TJPBaseSectionModelProtocol>

- (instancetype)initWithCellModels:(NSArray <id<TJPBaseCellModelProtocol>>*)cellModels;

@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) CGFloat sectionHeaderHeight;
@property (nonatomic, assign) CGFloat sectionFooterHeight;


@end

NS_ASSUME_NONNULL_END
