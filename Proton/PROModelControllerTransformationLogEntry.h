//
//  PROModelControllerTransformationLogEntry.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLogEntry.h"

@class PROModelController;
@class PROUniqueIdentifier;

/**
 * Private transformation log entry class used by
 * <PROModelControllerTransformationLog>.
 */
@interface PROModelControllerTransformationLogEntry : PROTransformationLogEntry <NSCoding>

/**
 * @name Model Controller
 */

/**
 * The unique identifier of the model controller to which this log entry
 * applies.
 *
 * This is used to restore model controller identifiers when moving across the
 * transformation log.
 */
@property (nonatomic, copy, readonly) PROUniqueIdentifier *modelControllerIdentifier;

/**
 * Fills in the receiver's <modelControllerIdentifier> and
 * <logEntriesByModelControllerKey> using information from the given model
 * controller.
 *
 * To preserve the appearance of immutability, this method should only be
 * invoked **once** (typically very shortly after initialization).
 *
 * @param modelController A model controller from which to retrieve information.
 */
- (void)captureModelController:(PROModelController *)modelController;

/**
 * @name Log Entry Tree
 */

/**
 * The log entry which the receiver is defined relative to.
 *
 * This property may be `nil` if the receiver is a root log entry (and thus has
 * no parent), or if the parent log entry has since been destroyed.
 */
@property (nonatomic, weak, readonly) PROModelControllerTransformationLogEntry *parentLogEntry;

/**
 * A dictionary containing arrays of <PROModelControllerTransformationLogEntry>
 * instances for every model controller managed by the receiver's model
 * controller.
 *
 * The keys of this dictionary will be the values returned by
 * <[PROModelController modelControllerKeysByModelKeyPath]>. The values will be
 * arrays containing instances of <PROModelControllerTransformationLogEntry>,
 * one for each model controller in the array at the corresponding key.
 *
 * This is used to also update the transformation logs of any managed model
 * controllers when moving across their parent's transformation log.
 */
@property (nonatomic, copy, readonly) NSDictionary *logEntriesByModelControllerKey;

@end
