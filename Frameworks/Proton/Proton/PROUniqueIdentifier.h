//
//  PROUniqueIdentifier.h
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PROUniqueIdentifier : NSObject <NSCoding, NSCopying>

/**
 * Initializes a unique identifier.
 */
- (id)init;

/**
 * Initializes a unique identifier by reading a standard string representation of a UUID,
 * such as that returned by <stringValue>.
 *
 * See http://en.wikipedia.org/wiki/Universally_unique_identifier#Definition
 *
 * @param uuidString A canonical string representation of a UUID.
 */
- (id)initWithString:(NSString *)uuidString;

/**
 * A string representation of the receiver, conforming to the standard representation for
 * a UUID.
 */
@property (nonatomic, copy, readonly) NSString *stringValue;

@end
