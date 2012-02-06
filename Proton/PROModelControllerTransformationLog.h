//
//  PROModelControllerTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"

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
 * @name Model Controller
 */

/**
 * The model controller that owns the receiver.
 */
@property (nonatomic, weak, readonly) PROModelController *modelController;

/**
 * @name Log Limiting
 */

/**
 * A dictionary containing any blocks passed to <[PROModelController
 * transformationLogEntryWithModelPointer:willRemoveLogEntryBlock:]>, keyed by
 * the log entry that they should be notified of.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *willRemoveLogEntryBlocksByLogEntry;

@end
