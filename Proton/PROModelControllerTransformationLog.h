//
//  PROModelControllerTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "PROModelControllerTransformationLogEntry.h"

@class PROModelController;

/**
 * Private transformation log class used by <PROModelController>.
 */
@interface PROModelControllerTransformationLog : PROTransformationLog <NSCoding>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver and associates it with the given model controller.
 *
 * @param modelController The model controller which will own the receiver.
 */
- (id)initWithModelController:(PROModelController *)modelController;

/**
 * @name Reading the Log
 */

/**
 * The last log entry that was recorded. This may be a root log entry if no
 * transformations have been recorded yet in the log.
 *
 * This property will never be `nil`.
 */
@property (nonatomic, copy, readonly) PROModelControllerTransformationLogEntry *latestLogEntry;

/**
 * @name Data Associated with Log Entries
 */

/**
 * Contains each <PROTransformationLogEntry> in the log as keys, associated with
 * a dictionary of arrays of the <PROModelController> instances that existed
 * after performing the transformation associated with the log entry.
 *
 * Each key in the nested dictionary is the key on the <modelController> at
 * which the controllers live, and the value is the array of model controllers
 * as they existed at the represented point in time.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *modelControllersByLogEntry;

/**
 * Contains each <PROTransformationLogEntry> in the log as keys, associated with
 * a dictionary of arrays of the <PROModelControllerTransformationLogEntry>
 * instances that each model controller had after the parent performed the
 * original transformation.
 *
 * Each key in the nested dictionary is the key on the <modelController> at
 * which the controllers live, and the value is the array of log entries as they
 * existed on each controller at the represented point in time.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *modelControllerLogEntriesByLogEntry;

/**
 * @name Model Controller
 */

/**
 * The model controller that owns the receiver.
 */
@property (nonatomic, weak, readonly) PROModelController *modelController;

@end
