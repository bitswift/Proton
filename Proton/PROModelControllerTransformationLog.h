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
 * @name Model Controller
 */

/**
 * The model controller that owns the receiver.
 */
@property (nonatomic, weak, readonly) PROModelController *modelController;

@end
