//
//  TJPBaseSectionModelProtocol.h
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>


NS_ASSUME_NONNULL_BEGIN

@protocol TJPBaseCellModelProtocol;


@protocol TJPBaseSectionModelProtocol <NSObject>


@required
@property (nonatomic, copy) NSArray<id<TJPBaseCellModelProtocol>> *cellModels;

@optional
@property (nonatomic, strong) RACCommand<id<TJPBaseSectionModelProtocol>, NSObject*>* selectedSectionCommand;

@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) CGFloat sectionHeaderHeight;
@property (nonatomic, assign) CGFloat sectionFooterHeight;

@end

NS_ASSUME_NONNULL_END
