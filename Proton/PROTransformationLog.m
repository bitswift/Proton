//
//  PROTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 28.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLog.h"
#import "PROKeyValueCodingMacros.h"
#import "PROMultipleTransformation.h"
#import "PROUniqueIdentifier.h"

@interface PROTransformationLog ()
@property (nonatomic, copy, readwrite) PROUniqueIdentifier *nextLogEntry;

/**
 * Contains <PROUniqueIdentifier> objects representing unique log entries,
 * ordered from oldest to newest.
 */
@property (nonatomic, strong, readonly) NSMutableOrderedSet *logEntries;

/**
 * Contains the <PROTransformation> objects associated with each unique
 * identifier in <logEntries>.
 *
 * This array must always contain exactly as many objects as <logEntries>.
 */
@property (nonatomic, strong, readonly) NSMutableArray *transformations;
@end

@implementation PROTransformationLog

#pragma mark Properties

@synthesize willRemoveLogEntryBlock = m_willRemoveLogEntryBlock;
@synthesize logEntries = m_logEntries;
@synthesize transformations = m_transformations;
@synthesize maximumNumberOfLogEntries = m_maximumNumberOfLogEntries;
@synthesize nextLogEntry = m_nextLogEntry;

- (void)setMaximumNumberOfLogEntries:(NSUInteger)maximum {
    m_maximumNumberOfLogEntries = maximum;

    if (m_maximumNumberOfLogEntries > 0 && self.logEntries.count > m_maximumNumberOfLogEntries) {
        NSRange rangeToRemove = NSMakeRange(0, m_maximumNumberOfLogEntries - self.logEntries.count);

        if (self.willRemoveLogEntryBlock) {
            [self.logEntries enumerateObjectsUsingBlock:^(PROUniqueIdentifier *entry, NSUInteger index, BOOL *stop){
                if (index >= NSMaxRange(rangeToRemove)) {
                    *stop = YES;
                    return;
                }

                self.willRemoveLogEntryBlock(entry);
            }];
        }
        
        [self.logEntries removeObjectsInRange:rangeToRemove];
        [self.transformations removeObjectsInRange:rangeToRemove];
    }
}

#pragma mark Initialization

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_logEntries = [[NSMutableOrderedSet alloc] init];
    m_transformations = [[NSMutableArray alloc] init];
    m_maximumNumberOfLogEntries = 50;

    self.nextLogEntry = [[PROUniqueIdentifier alloc] init];
    return self;
}

#pragma mark Reading

- (PROMultipleTransformation *)multipleTransformationStartingFromLogEntry:(id)logEntry; {
    NSParameterAssert([logEntry isKindOfClass:[PROUniqueIdentifier class]]);

    if ([logEntry isEqual:self.nextLogEntry]) {
        return [[PROMultipleTransformation alloc] init];
    }

    NSUInteger index = [self.logEntries indexOfObject:logEntry];
    if (index == NSNotFound)
        return nil;

    NSArray *transformations = [self.transformations subarrayWithRange:NSMakeRange(index, self.transformations.count - index)];
    return [[PROMultipleTransformation alloc] initWithTransformations:transformations];
}

#pragma mark Writing

- (void)addLogEntryWithTransformation:(PROTransformation *)transformation; {
    if (self.maximumNumberOfLogEntries) {
        NSUInteger logEntryCount = self.logEntries.count;
        if (logEntryCount + 1 > self.maximumNumberOfLogEntries) {
            if (self.willRemoveLogEntryBlock) {
                self.willRemoveLogEntryBlock(self.logEntries.firstObject);
            }

            [self.logEntries removeObjectAtIndex:0];
            [self.transformations removeObjectAtIndex:0];
        }
    }

    [self.logEntries addObject:self.nextLogEntry];
    [self.transformations addObject:transformation];

    // find a unique 'nextLogEntry' that doesn't conflict with anything already
    // in the log
    do {
        self.nextLogEntry = [[PROUniqueIdentifier alloc] init];
    } while ([self.logEntries containsObject:self.nextLogEntry]);
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PROTransformationLog *log = [[[self class] allocWithZone:zone] init];

    log.maximumNumberOfLogEntries = self.maximumNumberOfLogEntries;
    [log.logEntries unionOrderedSet:self.logEntries];
    [log.transformations addObjectsFromArray:self.transformations];

    // it seems like this shouldn't be copied, but the copied log will have all
    // of the same UUIDs recorded already anyways, so we want to ensure
    // consistency
    log.nextLogEntry = self.nextLogEntry;

    return log;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROUniqueIdentifier *nextLogEntry = [coder decodeObjectForKey:PROKeyForObject(self, nextLogEntry)];
    if (!nextLogEntry) {
        // this ID must remain valid across archiving, in order to ensure
        // a consistent view of the "latest" position in the log
        return nil;
    }

    NSOrderedSet *decodedLogEntries = [coder decodeObjectForKey:PROKeyForObject(self, logEntries)];
    NSArray *decodedTransformations = [coder decodeObjectForKey:PROKeyForObject(self, transformations)];
    
    if (decodedLogEntries.count != decodedTransformations.count)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    self.maximumNumberOfLogEntries = [coder decodeIntegerForKey:PROKeyForObject(self, maximumNumberOfLogEntries)];
    self.nextLogEntry = nextLogEntry;

    if (decodedLogEntries) {
        [self.logEntries unionOrderedSet:decodedLogEntries];
        [self.transformations addObjectsFromArray:decodedTransformations];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.maximumNumberOfLogEntries forKey:PROKeyForObject(self, maximumNumberOfLogEntries)];
    [coder encodeObject:self.nextLogEntry forKey:PROKeyForObject(self, nextLogEntry)];

    if (self.logEntries.count)
        [coder encodeObject:self.logEntries forKey:PROKeyForObject(self, logEntries)];

    if (self.transformations.count)
        [coder encodeObject:self.transformations forKey:PROKeyForObject(self, transformations)];
}

@end
