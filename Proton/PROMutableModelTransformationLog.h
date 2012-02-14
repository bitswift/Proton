//
//  PROMutableModelTransformationLog.h
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"

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

@end
