//
//  PROUniqueIdentifier.h
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Represents a UUID, a 128-bit identifier that is "practically unique". It is
 * highly improbable that any two <PROUniqueIdentifier> objects, generated on
 * the same machine or different ones, are equal, excepting when:
 *
 *  - One is a copy of the other.
 *  - One is initialized with the stringValue if another.
 *  - One is unarchived from the archive data of another.
 *  - Both were initialized with the same non-nil string.
 */
@interface PROUniqueIdentifier : NSObject <NSCoding, NSCopying>

/**
 * Initializes a new unique identifier, different from any previously ceated.
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
