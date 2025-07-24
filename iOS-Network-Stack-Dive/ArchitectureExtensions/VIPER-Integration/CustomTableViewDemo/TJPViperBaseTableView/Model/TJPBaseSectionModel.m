//
//  TJPBaseSectionModel.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/7/24.
//

#import "TJPBaseSectionModel.h"

@implementation TJPBaseSectionModel
@synthesize cellModels;

- (instancetype)initWithCellModels:(NSArray <id<TJPBaseCellModelProtocol>>*)cellModels {
    if (self = [super init]) {
        self.cellModels = cellModels;
    }
    return self;
}

@end
