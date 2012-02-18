//
//  PROMutableModelTransformationLogEntry.h
//  Proton
//
//  Created by Justin Spahr-Summers on 15.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLogEntry.h"

@class PROUniqueIdentifier;

/**
 * Private log entry class used in a <PROMutableModelTransformationLog>.
 *
 * This subclass adds the ability to identify the <PROMutableModel> to which it
 * applies.
 */
@interface PROMutableModelTransformationLogEntry : PROTransformationLogEntry <NSCoding>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver with the given log entry as its parent, and the
 * given UUID for a mutable model.
 *
 * @param parentLogEntry The log entry which the receiver will be defined
 * relative to.
 * @param mutableModelUniqueIdentifier The <[PROMutableModel uniqueIdentifier]>
 * of the model that the receiver applies to.
 */
- (id)initWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry mutableModelUniqueIdentifier:(PROUniqueIdentifier *)mutableModelUniqueIdentifier;

/**
 * @name Identification
 */

/**
 * The unique identifier for this log entry's <PROMutableModel>.
 */
@property (nonatomic, copy, readonly) PROUniqueIdentifier *mutableModelUniqueIdentifier;

@end
