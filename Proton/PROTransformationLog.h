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
 * Returns an opaque object representing the next log entry that will be
 * recorded. This method will never return `nil`.
 *
 * This method can be used to record the current position of the log.
 */
@property (nonatomic, copy, readonly) id nextLogEntry;

/**
 * Returns a <PROMultipleTransformation> that represents the transformations in
 * the log beginning from the given log entry and continuing to the end of the
 * log. If the log entry has been deleted, `nil` is returned.
 *
 * If the current value of <nextLogEntry> is passed into this method, an empty
 * transformation is returned.
 *
 * @param logEntry The log entry from which to start the transformation.
 */
- (PROMultipleTransformation *)multipleTransformationStartingFromLogEntry:(id)logEntry;

/**
 * @name Adding to the Log
 */

/**
 * Records the given transformation into the log and updates <nextLogEntry>.
 * 
 * @param transformation The transformation to append to the log.
 */
- (void)addLogEntryWithTransformation:(PROTransformation *)transformation;

/**
 * @name Log Limiting
 */

/**
 * The maximum number of log entries to store, or zero to disable limiting of
 * the log.
 *
 * If adding a new entry would push the log over the limit, the oldest log entry
 * is discarded, but only after invoking the <willRemoveLogEntryBlock> with that
 * entry.
 *
 * The default value for this property is 50.
 */
@property (nonatomic, assign) NSUInteger maximumNumberOfLogEntries;

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
@property (nonatomic, copy) void (^willRemoveLogEntryBlock)(id);

@end
