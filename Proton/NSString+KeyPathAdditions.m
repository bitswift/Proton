//
//  NSString+KeyPathAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 31.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSString+KeyPathAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSString, KeyPathAdditions)

#pragma mark Appending

- (NSString *)stringByAppendingKeyPathComponent:(NSString *)key; {
    NSParameterAssert(key.length);

    if (self.length)
        return [NSString stringWithFormat:@"%@.%@", self, key];
    else
        return [key copy];
}

@end
