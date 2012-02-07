//
//  PROModelControllerTransformationLogEntry.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLogEntry.h"

@class PROUniqueIdentifier;

/**
 * Represents a reference into the transformation log of a <PROModelController>,
 * which can be used to retrieve any version of the <[PROModelController model]>
 * with minimal data duplication.
 *
 * Log entry references are extremely cheap, but are only valid with respect to
 * a model controller, and only as long as the underlying transformation log
 * entry remains valid on the model controller. For this reason, model data
 * should almost always be saved alongside a log entry, in case the reference is
 * no longer valid when decoded.
 *
 * Log entries are valid across application launches and processes, as long as
 * the associated model controller is also persisted and restored.
 *
 * This class should not be subclassed.
 */
@interface PROModelControllerTransformationLogEntry : PROTransformationLogEntry

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
 * @name Log Entry Tree
 */

/**
 * The log entry which the receiver is defined relative to.
 *
 * This property may be `nil` if the receiver is a root log entry (and thus has
 * no parent), or if the parent log entry has since been destroyed.
 */
@property (nonatomic, weak, readonly) PROModelControllerTransformationLogEntry *parentLogEntry;
@end
