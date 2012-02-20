//
//  NSArray+SearchAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 19.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSArray` that provide additional or more powerful searching
 * functionality.
 */
@interface NSArray (SearchAdditions)

/**
 * Invokes <longestSubarrayCommonWithArray:subarrayRange:> with `NULL` range
 * pointers.
 */
- (NSArray *)longestSubarrayCommonWithArray:(NSArray *)otherArray;

/**
 * Returns the longest subarray that the receiver has in common with the given
 * array, or `nil` if the two arrays have nothing in common.
 *
 * The subarray may start at different indexes in each array. Comparison of each
 * object in the subarray is doing using `isEqual:`.
 *
 * @param otherArray The array to compare with the receiver.
 * @param rangeInReceiver If not `NULL`, this will be set to the range in the
 * receiver at which the returned subarray exists. If this method returns `nil`,
 * the `location` of the range will be `NSNotFound`.
 * @param rangeInOtherArray If not `NULL`, this will be set to the range in
 * `otherArray` at which the returned subarray exists. If this method returns
 * `nil`, the `location` of the range will be `NSNotFound`.
 */
- (NSArray *)longestSubarrayCommonWithArray:(NSArray *)otherArray rangeInReceiver:(NSRangePointer)rangeInReceiver rangeInOtherArray:(NSRangePointer)rangeInOtherArray;

@end
