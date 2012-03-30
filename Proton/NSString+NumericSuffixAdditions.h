//
//  NSString+NumericSuffixAdditions.h
//  Proton
//
//  Created by Josh Vera on 2/7/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extends `NSString` with support for creating strings with unique numeric
 * suffixes.
 */
@interface NSString (NumericSuffixAdditions)

/**
 * @name Creating Strings with Numeric Suffixes
 */

/**
 * Returns a string with a numeric suffix that does not conflict with other
 * numeric suffixes in `strings`.
 *
 * @param strings An set of strings with which the returned string should not conflict.
 */
- (NSString *)stringByAddingNumericSuffixNotConflictingWithStrings:(NSSet *)strings;

/**
 * Returns a string with a numeric suffix that does not conflict with other
 * numeric suffixes in `strings`.
 *
 * @param strings A set of strings with which the returned string should not conflict.
 * @param lengthConstraint The maximum length of the return value.
 */
- (NSString *)stringByAddingNumericSuffixNotConflictingWithStrings:(NSSet *)strings constrainedToLength:(NSUInteger)lengthConstraint;

@end
