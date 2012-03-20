//
//  NSArray+IndexPathAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 19.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSArray+IndexPathAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSArray, IndexPathAdditions)

- (id)objectAtIndexPath:(NSIndexPath *)indexPath; {
    return [self objectAtIndexPath:indexPath nodeKeyPath:nil];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath nodeKeyPath:(NSString *)nodeKeyPath; {
    NSParameterAssert(indexPath);

    NSUInteger length = indexPath.length;

    id object = self;
    if (length) {
        NSUInteger indexes[length];
        [indexPath getIndexes:indexes];

        for (NSUInteger i = 0; i < length; ++i) {
            if (![object isKindOfClass:[NSArray class]])
                return nil;

            NSUInteger index = indexes[i];
            object = [object objectAtIndex:index];

            if (i + 1 < length && nodeKeyPath)
                object = [object valueForKeyPath:nodeKeyPath];
        }
    }

    return object;
}

@end
