//
//  PROTransformationLogEntry.h
//  Proton
//
//  Created by Justin Spahr-Summers on 02.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROUniqueIdentifier;

/**
 * A single entry from a <PROTransformationLog>.
 *
 * Log entries have a unique identifier and a reference to their parent log
 * entry, which is enough information to reconstruct any point in
 * a transformation log, even across archiving or between processes.
 *
 * Log entries do not contain information about the actual <PROTransformation>
 * from a given point in the log, since a `PROTransformationLogEntry` is
 * intended to be extremely lightweight, and may continue to exist even after
 * the log is trimmed to conserve space.
 *
 * This class is thread-safe.
 */
@interface PROTransformationLogEntry : NSObject <NSCoding, NSCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver as a root log entry (one with no parent).
 */
- (id)init;

/**
 * Initializes the receiver with the given log entry as its parent.
 *
 * This is the designated initializer for this class.
 *
 * @param parentLogEntry The log entry which the receiver will be defined
 * relative to.
 */
- (id)initWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry;

/**
 * @name Identification
 */

/**
 * The unique identifier for this log entry.
 *
 * This identifier will be unique across application launches and between
 * processes on the same machine, but not necessarily between different
 * machines.
 */
@property (nonatomic, copy, readonly) PROUniqueIdentifier *uniqueIdentifier;

/**
 * @name Log Entry Tree
 */

/**
 * The log entry which the receiver is defined relative to.
 *
 * This property may be `nil` if the receiver is a root log entry (and thus has
 * no parent), or if the parent log entry has since been destroyed.
 */
@property (nonatomic, weak, readonly) PROTransformationLogEntry *parentLogEntry;

/**
 * Returns whether the receiver is equal to or a descendant of the given log
 * entry.
 *
 * This method works by traversing the <parentLogEntry> until the given entry is
 * found, or until no more log entries exist.
 */
- (BOOL)isDescendantOfLogEntry:(PROTransformationLogEntry *)ancestorLogEntry;

@end
