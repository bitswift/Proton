//
//  NSIndexPath+TransformationAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 19.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSIndexPath+TransformationAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSIndexPath, TransformationAdditions)

- (NSIndexPath *)indexPathByPrependingIndex:(NSUInteger)index; {
    NSUInteger length = self.length + 1;

    NSUInteger indexes[length];
    [self getIndexes:indexes + 1];

    indexes[0] = index;
    return [[self class] indexPathWithIndexes:indexes length:length];
}

- (NSIndexPath *)indexPathByRemovingFirstIndex; {
    if (self.length <= 1)
        return [[self class] indexPathWithIndexes:NULL length:0];

    NSUInteger indexes[self.length];
    [self getIndexes:indexes];

    return [[self class] indexPathWithIndexes:indexes + 1 length:self.length - 1];
}

@end
