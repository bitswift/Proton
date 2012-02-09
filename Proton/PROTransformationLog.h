//
//  PROTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 28.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROMultipleTransformation;
@class PROTransformation;
@class PROTransformationLogEntry;

/**
 * Represents a log of <PROTransformation> objects.
 *
 * This log is an optionally size-limited list of transformations that record
 * changes to an object over time. At any time, a <PROMultipleTransformation>
 * can be constructed from a range of the log, and used to "play back" changes
 * to the transformed object.
 *
 * This class is not thread-safe.
 */
@interface PROTransformationLog : NSObject <NSCoding, NSCopying>

/**
 * @name Reading the Log
 */

/**
 * The last log entry that was recorded. This may be a root log entry if no
 * transformations have been recorded yet in the log.
 *
 * This property will never be `nil`.
 */
@property (nonatomic, copy, readonly) PROTransformationLogEntry *latestLogEntry;

/**
 * Returns a <PROMultipleTransformation> that contains the transformations in
 * the log starting from `fromLogEntry`, exclusive, and continuing until
 * `toLogEntry`, inclusive. If any transformations in the range have been
 * removed, `nil` is returned.
 *
 * If `fromLogEntry` is equal to `toLogEntry`, an empty transformation is
 * returned.
 *
 * @param fromLogEntry The log entry from which to start accumulating
 * transformations. The transformation associated with this log entry is _not_
 * included in the result.
 * @param toLogEntry The log entry at which to stop accumulating
 * transformations. The transformation associated with this log entry _is_
 * included in the result.
 */
- (PROMultipleTransformation *)multipleTransformationFromLogEntry:(PROTransformationLogEntry *)fromLogEntry toLogEntry:(PROTransformationLogEntry *)toLogEntry;

/**
 * @name Modifying the Log
 */

/**
 * Creates a new <PROTransformationLogEntry> associated with the given
 * transformation, and records it into the log.
 *
 * <latestLogEntry> will be set to the new <PROTransformationLogEntry> object.
 * 
 * @param transformation The transformation to append to the log.
 */
- (void)appendTransformation:(PROTransformation *)transformation;

/**
 * Appends the given log entry to the log and updates the receiver's
 * <latestLogEntry>. If the entry already existed in the log, any data
 * associated with it is destroyed.
 *
 * This method is primarily meant to be overridden, but can be invoked
 * externally to forcibly append a specific log entry or clear its associated
 * data. Use with care.
 *
 * @param logEntry The entry to append to the log. This will be the
 * <latestLogEntry> after this method completes.
 */
- (void)addOrReplaceLogEntry:(PROTransformationLogEntry *)logEntry;

/**
 * Moves the receiver's <latestLogEntry> to the given entry, if possible.
 * Returns `NO` without doing anything if it would be invalid to move to the
 * given log entry.
 *
 * @param logEntry The log entry to set as the receiver's <latestLogEntry>. This
 * entry must either be a new root log entry, or must already be in the log.
 */
- (BOOL)moveToLogEntry:(PROTransformationLogEntry *)logEntry;

/**
 * Removes all log entries _except the <latestLogEntry>_, and destroys any data
 * that was associated with the removed log entries.
 */
- (void)removeAllLogEntries;

/**
 * Removes the given log entry and any associated data. If the entry does not
 * exist in the log, nothing happens.
 *
 * This method is primarily meant to be overridden, but can be invoked
 * externally to forcibly remove a specific log entry. Use with care.
 *
 * @param logEntry The entry to remove from the log.
 *
 * @warning **Important:** The behavior of removing the <latestLogEntry> is
 * undefined.
 */
- (void)removeLogEntry:(PROTransformationLogEntry *)logEntry;

/**
 * @name Log Limiting
 */

/**
 * The maximum number of log entries to store in memory, or zero to disable
 * limiting of the log in memory.
 *
 * If adding a new entry would push the log over the limit, the oldest log entry
 * is discarded, but only after invoking the <willRemoveLogEntryBlock> with that
 * entry.
 *
 * To apply a limit to the log only when archived, use
 * <maximumNumberOfArchivedLogEntries>.
 *
 * The default value for this property is zero.
 */
@property (nonatomic, assign) NSUInteger maximumNumberOfLogEntries;

/**
 * The maximum number of log entries to store when the receiver is encoded in an
 * archive, or zero to disable limiting of the archived log.
 *
 * This property has no effect if set equal to or higher than
 * <maximumNumberOfLogEntries>.
 *
 * The default value for this property is zero.
 */
@property (nonatomic, assign) NSUInteger maximumNumberOfArchivedLogEntries;

/**
 * The log entries in the receiver that would be archived with the log, based on
 * the value of <maximumNumberOfArchivedLogEntries>.
 */
@property (nonatomic, copy, readonly) NSOrderedSet *archivableLogEntries;

/**
 * If not `nil`, this block is invoked immediately before removing an old log
 * entry.
 *
 * The block will be passed the log entry that is about to be deleted. The log
 * entry is guaranteed to remain valid while the block executes. You must not
 * modify the transformation log from this block.
 * 
 * @warning **Important:** This block will not be copied or archived with the
 * transformation log.
 */
@property (nonatomic, copy) void (^willRemoveLogEntryBlock)(PROTransformationLogEntry *logEntry);

/**
 * @name Subclassing
 */

/**
 * Creates and returns a new <PROTransformationLogEntry> as a child of the given
 * log entry.
 *
 * Subclasses may override this method to change how log entries are
 * instantiated.
 *
 * This method is not meant to be invoked by consumers of this class, as it does
 * not provide any additional functionality over <[PROTransformationLogEntry
 * initWithParentLogEntry:]> in its default implementation.
 *
 * @param parentLogEntry The log entry that the new entry should be a child of,
 * or `nil` if the new entry should be a root entry.
 */
- (PROTransformationLogEntry *)logEntryWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry;

@end
