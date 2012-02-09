//
//  PROTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 28.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"
#import "PROMultipleTransformation.h"
#import "PROTransformationLogEntry.h"
#import "PROUniqueIdentifier.h"

@interface PROTransformationLog ()
@property (nonatomic, copy, readwrite) PROTransformationLogEntry *latestLogEntry;

/**
 * Contains <PROTransformationLogEntry> instances.
 *
 * When discarding log entries, this set is ordered such that the first items
 * should be discarded first, and the last items discarded last.
 */
@property (nonatomic, strong, readonly) NSMutableOrderedSet *logEntries;

/**
 * Contains the <PROTransformation> objects associated with each
 * <PROTransformationLogEntry>.
 *
 * This dictionary should never have more objects than <logEntries>.
 *
 * Note that root log entries do not have associated transformations.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *transformationsByLogEntry;

/**
 * Ensures that the receiver has free space for the given number of additional
 * log entries, discarding previous ones as necessary.
 *
 * If the given number is equal to or greater than the maximum number of log
 * entries, the entire log is cleared out.
 */
- (void)prepareForAdditionalEntries:(NSUInteger)additionalEntries;
@end

@implementation PROTransformationLog

#pragma mark Properties

@synthesize logEntries = m_logEntries;
@synthesize transformationsByLogEntry = m_transformationsByLogEntry;
@synthesize latestLogEntry = m_latestLogEntry;
@synthesize maximumNumberOfLogEntries = m_maximumNumberOfLogEntries;
@synthesize maximumNumberOfArchivedLogEntries = m_maximumNumberOfArchivedLogEntries;
@synthesize willRemoveLogEntryBlock = m_willRemoveLogEntryBlock;

- (NSOrderedSet *)archivableLogEntries {
    if (self.maximumNumberOfArchivedLogEntries && self.logEntries.count > self.maximumNumberOfArchivedLogEntries) {
        NSRange range = NSMakeRange(self.logEntries.count - self.maximumNumberOfArchivedLogEntries, self.maximumNumberOfArchivedLogEntries);
        return [[NSOrderedSet alloc] initWithOrderedSet:self.logEntries range:range copyItems:NO];
    } else {
        return [self.logEntries copy];
    }
}

- (void)setMaximumNumberOfLogEntries:(NSUInteger)maximum {
    m_maximumNumberOfLogEntries = maximum;

    // trim the log if necessary
    [self prepareForAdditionalEntries:0];
}

#pragma mark Initialization

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_logEntries = [[NSMutableOrderedSet alloc] initWithCapacity:m_maximumNumberOfLogEntries];
    m_transformationsByLogEntry = [[NSMutableDictionary alloc] initWithCapacity:m_maximumNumberOfLogEntries];

    // move to an initial root log entry
    BOOL success = [self moveToLogEntry:[self logEntryWithParentLogEntry:nil]];
    if (!PROAssert(success, @"Could not move to initial root log entry"))
        return nil;

    return self;
}

#pragma mark Reading

- (PROMultipleTransformation *)multipleTransformationFromLogEntry:(PROTransformationLogEntry *)fromLogEntry toLogEntry:(PROTransformationLogEntry *)toLogEntry; {
    NSParameterAssert(fromLogEntry != nil);
    NSParameterAssert(toLogEntry != nil);

    PROTransformationLogEntry *commonAncestorEntry = toLogEntry;

    while (![fromLogEntry isDescendantOfLogEntry:commonAncestorEntry]) {
        commonAncestorEntry = commonAncestorEntry.parentLogEntry;
        if (!commonAncestorEntry)
            return nil;
    }

    NSMutableArray *transformations = [[NSMutableArray alloc] init];
    PROTransformationLogEntry *currentEntry = fromLogEntry;

    // accumulate reverse transformations from 'fromLogEntry' up to the common
    // ancestor
    while (![currentEntry isEqual:commonAncestorEntry]) {
        if (![self.logEntries containsObject:currentEntry]) {
            return nil;
        }

        PROTransformation *transformation = [self.transformationsByLogEntry objectForKey:currentEntry];
        if (transformation)
            [transformations addObject:transformation.reverseTransformation];

        currentEntry = currentEntry.parentLogEntry;
        NSAssert(currentEntry, @"Parent entry should not be nil after already finding a common ancestor");
    }

    // then accumulate forward transformations from the common ancestor down to
    // 'toLogEntry' (but we have to traverse in the opposite direction, so
    // insert in reverse order)
    
    NSUInteger insertIndex = transformations.count;

    currentEntry = toLogEntry;
    while (![currentEntry isEqual:commonAncestorEntry]) {
        if (![self.logEntries containsObject:currentEntry]) {
            return nil;
        }

        PROTransformation *transformation = [self.transformationsByLogEntry objectForKey:currentEntry];
        if (transformation)
            [transformations insertObject:transformation atIndex:insertIndex];

        currentEntry = currentEntry.parentLogEntry;
        NSAssert(currentEntry, @"Parent entry should not be nil after already finding a common ancestor");
    }

    return [[PROMultipleTransformation alloc] initWithTransformations:transformations];
}

#pragma mark Writing

- (void)appendTransformation:(PROTransformation *)transformation; {
    NSParameterAssert(transformation != nil);

    PROTransformationLogEntry *newEntry = [self logEntryWithParentLogEntry:self.latestLogEntry];
    [self addOrReplaceLogEntry:newEntry];
    [self.transformationsByLogEntry setObject:transformation forKey:newEntry];
}

- (void)addOrReplaceLogEntry:(PROTransformationLogEntry *)logEntry; {
    NSParameterAssert(logEntry != nil);

    if (![self.logEntries containsObject:logEntry]) {
        [self prepareForAdditionalEntries:1];
        [self.logEntries addObject:logEntry];
    }

    [self.transformationsByLogEntry removeObjectForKey:logEntry];
    self.latestLogEntry = logEntry;
}

- (BOOL)moveToLogEntry:(PROTransformationLogEntry *)logEntry; {
    NSParameterAssert(logEntry != nil);

    if (!logEntry.parentLogEntry) {
        [self addOrReplaceLogEntry:logEntry];
        return YES;
    }
        
    // if this isn't a root, this entry must already exist in the log
    if (![self.logEntries containsObject:logEntry])
        return NO;

    self.latestLogEntry = logEntry;
    return YES;
}

- (void)prepareForAdditionalEntries:(NSUInteger)additionalEntries; {
    if (!self.maximumNumberOfLogEntries || self.logEntries.count + additionalEntries <= self.maximumNumberOfLogEntries) {
        // no expansion needed
        return;
    }

    NSRange rangeToRemove = NSMakeRange(0, self.logEntries.count + additionalEntries - self.maximumNumberOfLogEntries);
    NSIndexSet *indexesToRemove = [NSIndexSet indexSetWithIndexesInRange:rangeToRemove];

    NSArray *entriesToRemove = [self.logEntries objectsAtIndexes:indexesToRemove];
    [entriesToRemove enumerateObjectsUsingBlock:^(PROTransformationLogEntry *entry, NSUInteger index, BOOL *stop){
        [self removeLogEntry:entry];
    }];
}

- (void)removeLogEntry:(PROTransformationLogEntry *)logEntry; {
    NSParameterAssert(logEntry != nil);

    NSUInteger entryIndex = [self.logEntries indexOfObject:logEntry];
    if (entryIndex == NSNotFound)
        return;

    if (self.willRemoveLogEntryBlock)
        self.willRemoveLogEntryBlock(logEntry);

    [self.logEntries removeObjectAtIndex:entryIndex];
    [self.transformationsByLogEntry removeObjectForKey:logEntry];
}

#pragma mark Subclassing

- (PROTransformationLogEntry *)logEntryWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry; {
    return [[PROTransformationLogEntry alloc] initWithParentLogEntry:parentLogEntry];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PROTransformationLog *log = [[[self class] allocWithZone:zone] init];

    [log.logEntries removeAllObjects];
    [log.logEntries unionOrderedSet:self.logEntries];
    [log.transformationsByLogEntry setDictionary:self.transformationsByLogEntry];

    log.latestLogEntry = self.latestLogEntry;
    log.maximumNumberOfLogEntries = self.maximumNumberOfLogEntries;
    log.maximumNumberOfArchivedLogEntries = self.maximumNumberOfArchivedLogEntries;

    return log;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROTransformationLogEntry *latestLogEntry = [coder decodeObjectForKey:PROKeyForObject(self, latestLogEntry)];
    if (!latestLogEntry)
        return nil;

    NSOrderedSet *logEntries = [coder decodeObjectForKey:PROKeyForObject(self, logEntries)];
    if (!logEntries)
        return nil;

    NSDictionary *transformationsByLogEntry = [coder decodeObjectForKey:PROKeyForObject(self, transformationsByLogEntry)];
    if (!transformationsByLogEntry)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    [self.logEntries removeAllObjects];
    [self.logEntries unionOrderedSet:logEntries];
    [self.transformationsByLogEntry setDictionary:transformationsByLogEntry];

    self.latestLogEntry = latestLogEntry;
    self.maximumNumberOfLogEntries = [coder decodeIntegerForKey:PROKeyForObject(self, maximumNumberOfLogEntries)];
    self.maximumNumberOfArchivedLogEntries = [coder decodeIntegerForKey:PROKeyForObject(self, maximumNumberOfArchivedLogEntries)];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.latestLogEntry forKey:PROKeyForObject(self, latestLogEntry)];

    NSOrderedSet *limitedEntries = self.archivableLogEntries;
    [coder encodeObject:limitedEntries forKey:PROKeyForObject(self, logEntries)];

    NSDictionary *limitedTransformations = [self.transformationsByLogEntry filterEntriesUsingBlock:^(PROTransformationLogEntry *logEntry, PROTransformation *transformation){
        return [limitedEntries containsObject:logEntry];
    }];

    [coder encodeObject:limitedTransformations forKey:PROKeyForObject(self, transformationsByLogEntry)];

    [coder encodeInteger:self.maximumNumberOfLogEntries forKey:PROKeyForObject(self, maximumNumberOfLogEntries)];
    [coder encodeInteger:self.maximumNumberOfArchivedLogEntries forKey:PROKeyForObject(self, maximumNumberOfArchivedLogEntries)];
}

#pragma mark NSObject overrides

- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc] initWithFormat:@"<%@: %p>{", [self class], (__bridge void *)self];

    [self.logEntries enumerateObjectsUsingBlock:^(PROTransformationLogEntry *logEntry, NSUInteger index, BOOL *stop){
        PROTransformation *transformation = [self.transformationsByLogEntry objectForKey:logEntry];
        PROTransformationLogEntry *parentLogEntry = logEntry.parentLogEntry;

        if (parentLogEntry)
            [description appendFormat:@"\n\t%@ (parent: %@) = %@", logEntry.uniqueIdentifier, parentLogEntry.uniqueIdentifier, transformation];
        else
            [description appendFormat:@"\n\t%@ (no parent) = %@", logEntry.uniqueIdentifier, transformation];
    }];

    [description appendString:@"\n}"];
    return description;
}

- (NSUInteger)hash {
    return self.logEntries.hash;
}

- (BOOL)isEqual:(PROTransformationLog *)log {
    if (![log isKindOfClass:[PROTransformationLog class]])
        return NO;

    if (self.maximumNumberOfLogEntries != log.maximumNumberOfLogEntries)
        return NO;

    if (self.maximumNumberOfArchivedLogEntries != log.maximumNumberOfArchivedLogEntries)
        return NO;

    if (![self.latestLogEntry isEqual:log.latestLogEntry])
        return NO;

    if (![self.logEntries isEqual:log.logEntries])
        return NO;

    if (![self.transformationsByLogEntry isEqual:log.transformationsByLogEntry])
        return NO;

    return YES;
}

@end
