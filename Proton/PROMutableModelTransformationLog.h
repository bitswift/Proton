//
//  PROMutableModelTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"

@class PROMutableModel;

/**
 * Private transformation log class used by <PROMutableModel>.
 */
@interface PROMutableModelTransformationLog : PROTransformationLog <NSCoding>

/**
 * @name Data Associated with Log Entries
 */

/**
 * Contains <PROMutableModelTransformationResultInfo> objects keyed by each
 * <PROTransformationLogEntry> in the log.
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
- (PROTransformationLogEntry *)logEntryWithMutableModel:(PROMutableModel *)mutableModel childLogEntry:(PROTransformationLogEntry *)logEntry;

@end
