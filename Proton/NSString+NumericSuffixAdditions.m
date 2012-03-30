//
//  NSString+NumericSuffixAdditions.m
//  Proton
//
//  Created by Josh Vera on 2/7/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSString+NumericSuffixAdditions.h"
#import "EXTSafeCategory.h"
#import "Foundation+LocalizationAdditions.h"

@safecategory (NSString, NumericSuffixAdditions)

- (NSString *)stringByAddingNumericSuffixNotConflictingWithStrings:(NSSet *)strings {
    return [self stringByAddingNumericSuffixNotConflictingWithStrings:strings constrainedToLength:NSUIntegerMax];
}

- (NSString *)stringByAddingNumericSuffixNotConflictingWithStrings:(NSSet *)strings constrainedToLength:(NSUInteger)lengthConstraint; {
    NSString *name = [self copy];

    // `name` doesn't conflict with the set so return it.
    if (![strings containsObject:name])
        return name;

    NSString *baseName = name;
    unsigned nameSuffix = 2;

    // Find whitespace followed by at least one number at the end of the string
    NSRange numberRange = [name rangeOfString:@"\\s\\d+$" options:NSRegularExpressionSearch];
    if (numberRange.location != NSNotFound) {
        NSInteger existingNameSuffix = [[name substringFromIndex:numberRange.location + 1] integerValue];
        baseName = [name substringToIndex:numberRange.location];
        nameSuffix = (unsigned)existingNameSuffix + 1;
    }

    NSString *format = PROLocalizedStringWithDefaultValue(
        @"auto_rename.format",
        @"%1$@ %2$u",
        @"The format for automatically renamed labels provided by the user, where the old label is argument 1, and the number of copies is argument 2."
    );

    do {
        name = [NSString stringWithFormat:format, baseName, nameSuffix];
        // If we made a name that's too long, truncate the baseName and do better
        if ([name length] > lengthConstraint) {
            NSUInteger overshoot = [name length] - lengthConstraint;
            baseName = [baseName substringToIndex:[baseName length] - overshoot];
            name = [NSString stringWithFormat:format, baseName, nameSuffix];
        }
        ++nameSuffix;
    } while ([strings containsObject:name]);

    return name;
}

@end
