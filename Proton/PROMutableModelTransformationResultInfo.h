//
//  PROMutableModelTransformationResultInfo.h
//  Proton
//
//  Created by Justin Spahr-Summers on 14.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Private class used with <PROMutableModelTransformationLog> to store
 * information about the state of a <PROMutableModel> after having
 * a transformation applied to it.
 */
@interface PROMutableModelTransformationResultInfo : NSObject <NSCopying, NSCoding>

/**
 * @name Mutable Models
 */

/**
 * Contains the <PROMutableModel> instances that existed after applying the
 * transformation.
 *
 * The keys of this dictionary should be some or all of those from <[PROModel
 * modelClassesByKey]> on the <PROModel> underlying the mutable model that was
 * transformed.
 */
@property (nonatomic, copy) NSDictionary *mutableModelsByKey;

/**
 * @name Log Entries
 */

/**
 * Contains the <PROTransformationLogEntry> instances that each
 * <PROMutableModel> had after applying the transformation to the parent.
 *
 * This dictionary does _not_ copy its <PROMutableModel> keys, and uses pointer
 * equality to compare them, thus ensuring quick lookup without needlessly
 * allocating data.
 */
@property (nonatomic, copy, readonly) NSDictionary *logEntriesByMutableModel;

/**
 * Sets <logEntriesByMutableModels> with the given log entries (which will
 * become the values) and mutable models (which will become the keys).
 *
 * This is used to create <logEntriesByMutableModel> without copying the
 * <PROMutableModel> objects.
 *
 * @param logEntries An array of <PROTransformationLogEntry> objects, one for
 * each mutable model.
 * @param mutableModels An array of <PROMutableModel> objects, which each of the
 * log entries refer to.
 */
- (void)setLogEntries:(NSArray *)logEntries forMutableModels:(NSArray *)mutableModels;

@end
