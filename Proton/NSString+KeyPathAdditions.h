//
//  NSString+KeyPathAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 31.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSString` for working with key paths.
 */
@interface NSString (KeyPathAdditions)

/**
 * @name Appending Key Path Components
 */

/**
 * Returns a key path created by appending the given key to the receiver.
 *
 * If the receiver is non-empty, a period is appended to the string before the
 * key, to match the key path format used by key-value coding.
 *
 * @param key The key to append to the receiver.
 */
- (NSString *)stringByAppendingKeyPathComponent:(NSString *)key;

@end
