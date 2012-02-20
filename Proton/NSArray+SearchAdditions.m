//
//  NSArray+SearchAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 19.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSArray+SearchAdditions.h"
#import "EXTSafeCategory.h"
#import "EXTScope.h"
#import "PROAssert.h"

@safecategory (NSArray, SearchAdditions)

- (NSArray *)longestSubarrayCommonWithArray:(NSArray *)otherArray; {
    return [self longestSubarrayCommonWithArray:otherArray rangeInReceiver:NULL rangeInOtherArray:NULL];
}

- (NSArray *)longestSubarrayCommonWithArray:(NSArray *)otherArray rangeInReceiver:(NSRangePointer)rangeInReceiver rangeInOtherArray:(NSRangePointer)rangeInOtherArray; {
    if (!self.count || !otherArray.count) {
        if (rangeInReceiver)
            *rangeInReceiver = NSMakeRange(NSNotFound, 0);

        if (rangeInOtherArray)
            *rangeInOtherArray = NSMakeRange(NSNotFound, 0);

        return nil;
    }

    NSUInteger selfCount = self.count;
    NSUInteger otherCount = otherArray.count;
    
    __block NSUInteger *current = calloc(otherCount, sizeof(*current));
    if (!PROAssert(current, @"Could not allocate space for %lu integers", (unsigned long)otherCount))
        return nil;

    @onExit {
        free(current);
    };

    __block NSUInteger *previous = calloc(otherCount, sizeof(*previous));
    if (!PROAssert(previous, @"Could not allocate space for %lu integers", (unsigned long)otherCount))
        return nil;

    @onExit {
        free(previous);
    };

    __block NSRange range = NSMakeRange(NSNotFound, 0);
    __block NSUInteger otherArrayIndex = NSNotFound;

    [self enumerateObjectsUsingBlock:^(id selfObj, NSUInteger selfIndex, BOOL *stop){
        [otherArray enumerateObjectsUsingBlock:^(id otherObj, NSUInteger otherIndex, BOOL *stop){
            if (![selfObj isEqual:otherObj]) {
                current[otherIndex] = 0;
                return;
            }

            if (selfIndex == 0 || otherIndex == 0) {
                current[otherIndex] = 1;
            } else {
                current[otherIndex] = 1 + previous[otherIndex - 1];
            }

            if (current[otherIndex] > range.length) {
                NSUInteger currentLength = current[otherIndex];

                range = NSMakeRange(selfIndex + 1 - currentLength, currentLength);
                otherArrayIndex = otherIndex + 1 - currentLength;
            }
        }];

        NSUInteger *swap = current;
        current = previous;
        previous = swap;
    }];

    if (range.length > 0) {
        NSAssert(range.location != NSNotFound, @"Location of receiver range is NSNotFound even when length (%lu) is non-zero", (unsigned long)range.length);
        NSAssert(otherArrayIndex != NSNotFound, @"Location of other array range is NSNotFound even when length (%lu) is non-zero", (unsigned long)range.length);
    }

    if (rangeInReceiver)
        *rangeInReceiver = range;

    if (rangeInOtherArray)
        *rangeInOtherArray = NSMakeRange(otherArrayIndex, range.length);

    if (range.location == NSNotFound)
        return nil;
    else
        return [self subarrayWithRange:range];
}

@end
