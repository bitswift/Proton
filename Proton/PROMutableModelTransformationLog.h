//
//  PROMutableModelTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "PROMutableModelTransformationLogEntry.h"

/**
 * Private transformation log class used by <PROMutableModel>.
 */
@interface PROMutableModelTransformationLog : PROTransformationLog <NSCoding>

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
 * <PROTransformationLogEntry> in the log.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *transformationResultInfoByLogEntry;

@end
