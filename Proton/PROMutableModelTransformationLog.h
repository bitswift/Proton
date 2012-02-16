//
//  PROMutableModelTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "PROMutableModelTransformationLogEntry.h"

@class PROMutableModel;

/**
 * Private transformation log class used by <PROMutableModel>.
 */
@interface PROMutableModelTransformationLog : PROTransformationLog <NSCoding>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver with the given mutable model as its owner.
 *
 * @param mutableModel The <PROMutableModel> that owns the receiver.
 */
- (id)initWithMutableModel:(PROMutableModel *)mutableModel;

/**
 * @name Mutable Model
 */

/**
 * The model that owns this transformation log.
 */
@property (nonatomic, weak, readonly) PROMutableModel *mutableModel;

/**
 * @name Reading the Log
 */

/**
 * The last log entry that was recorded. This may be a root log entry if no
 * transformations have been recorded yet in the log.
 *
 * This property will never be `nil`.
 */
@property (nonatomic, copy, readonly) PROMutableModelTransformationLogEntry *latestLogEntry;

/**
 * @name Data Associated with Log Entries
 */

/**
 * Contains <PROMutableModelTransformationResultInfo> objects keyed by each
 * <PROMutableModelTransformationLogEntry> in the log.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *transformationResultInfoByLogEntry;

/**
 * Returns the newest entry from the log which has an associated
 * <PROMutableModelTransformationResultInfo> object containing the given log
 * entry, or `nil` if no such entry exists.
 *
 * @param mutableModel The <PROMutableModel> to which the given log entry
 * belongs.
 * @param logEntry A log entry to search for in
 * <[PROMutableModelTransformationResultInfo logEntriesByMutableModel]>.
 */
- (PROMutableModelTransformationLogEntry *)logEntryWithMutableModel:(PROMutableModel *)mutableModel childLogEntry:(PROMutableModelTransformationLogEntry *)logEntry;

@end
