//
//  PROModelControllerTransformationLogEntryPrivate.h
//  Proton
//
//  Created by Justin Spahr-Summers on 07.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelControllerTransformationLogEntry.h"

@class PROModelController;

/**
 * Private extensions to <PROModelControllerTransformationLogEntry> that need to
 * be available to other parts of the framework.
 */
@interface PROModelControllerTransformationLogEntry (Private)

/**
 * @name Model Controller
 */

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
 * @name Managed Model Controllers
 */

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
