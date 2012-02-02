//
//  PROTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 28.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "PROTransformationLogEntry.h"
#import "PROMultipleTransformation.h"
#import "PROUniqueIdentifier.h"

@implementation PROTransformationLog

#pragma mark Properties

@synthesize latestLogEntry = m_latestLogEntry;
@synthesize maximumNumberOfLogEntries = m_maximumNumberOfLogEntries;
@synthesize willRemoveLogEntryBlock = m_willRemoveLogEntryBlock;

#pragma mark Initialization

#pragma mark Reading

- (PROMultipleTransformation *)multipleTransformationFromLogEntry:(PROTransformationLogEntry *)fromLogEntry toLogEntry:(PROTransformationLogEntry *)toLogEntry; {
    return nil;
}

#pragma mark Writing

- (void)appendTransformation:(PROTransformation *)transformation; {
}

- (BOOL)moveToLogEntry:(PROTransformationLogEntry *)logEntry; {
    return NO;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return nil;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

#pragma mark NSObject overrides

@end
