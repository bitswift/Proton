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
 *
 * Setting this property will also copy any collection values.
 */
@property (nonatomic, copy) NSDictionary *mutableModelsByKey;

/**
 * @name Log Entries
 */

/**
 * Contains the <PROTransformationLogEntry> instances that each
 * <PROMutableModel> had after applying the transformation to the parent.
 */
@property (nonatomic, copy) NSDictionary *logEntriesByMutableModelUniqueIdentifier;

@end
