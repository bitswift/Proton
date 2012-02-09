//
//  PROModelControllerTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelControllerTransformationLog.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"
#import "PROModelController.h"
#import "PROModelControllerTransformationLogEntry.h"
#import "SDQueue.h"

@implementation PROModelControllerTransformationLog

#pragma mark Properties

@dynamic latestLogEntry;

@synthesize modelController = m_modelController;
@synthesize modelControllersByLogEntry = m_modelControllersByLogEntry;
@synthesize modelControllerLogEntriesByLogEntry = m_modelControllerLogEntriesByLogEntry;

#pragma mark Initialization

- (id)initWithModelController:(PROModelController *)modelController; {
    NSParameterAssert(modelController != nil);

    self = [self init];
    if (!self)
        return nil;

    m_modelController = modelController;
    m_modelControllersByLogEntry = [[NSMutableDictionary alloc] init];
    m_modelControllerLogEntriesByLogEntry = [[NSMutableDictionary alloc] init];

    return self;
}

#pragma mark Log Entries

- (void)addOrReplaceLogEntry:(PROModelControllerTransformationLogEntry *)logEntry; {
    [super addOrReplaceLogEntry:logEntry];
}

- (PROModelControllerTransformationLogEntry *)logEntryWithParentLogEntry:(PROModelControllerTransformationLogEntry *)parentLogEntry; {
    NSParameterAssert(!parentLogEntry || [parentLogEntry isKindOfClass:[PROModelControllerTransformationLogEntry class]]);
    
    return [[PROModelControllerTransformationLogEntry alloc] initWithParentLogEntry:parentLogEntry modelControllerIdentifier:self.modelController.uniqueIdentifier];
}

- (void)removeLogEntry:(PROModelControllerTransformationLogEntry *)logEntry; {
    [super removeLogEntry:logEntry];
    [self.modelControllersByLogEntry removeObjectForKey:logEntry];
    [self.modelControllerLogEntriesByLogEntry removeObjectForKey:logEntry];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    m_modelController = [coder decodeObjectForKey:PROKeyForObject(self, modelController)];
    m_modelControllersByLogEntry = [[coder decodeObjectForKey:PROKeyForObject(self, modelControllersByLogEntry)] mutableCopy];
    m_modelControllerLogEntriesByLogEntry = [[coder decodeObjectForKey:PROKeyForObject(self, modelControllerLogEntriesByLogEntry)] mutableCopy];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    if (self.modelController)
        [coder encodeObject:self.modelController forKey:PROKeyForObject(self, modelController)];

    NSOrderedSet *archivableEntries = self.archivableLogEntries;

    NSDictionary *limitedModelControllers = [self.modelControllersByLogEntry filterEntriesUsingBlock:^(PROModelControllerTransformationLogEntry *entry, id modelController){
        return [archivableEntries containsObject:entry];
    }];

    if (limitedModelControllers)
        [coder encodeObject:limitedModelControllers forKey:PROKeyForObject(self, modelControllersByLogEntry)];

    NSDictionary *limitedModelControllerLogEntries = [self.modelControllerLogEntriesByLogEntry filterEntriesUsingBlock:^(PROModelControllerTransformationLogEntry *entry, id modelControllerLogEntry){
        return [archivableEntries containsObject:entry];
    }];

    if (limitedModelControllerLogEntries)
        [coder encodeObject:limitedModelControllerLogEntries forKey:PROKeyForObject(self, modelControllerLogEntriesByLogEntry)];
}

#pragma mark NSObject overrides

- (BOOL)isEqual:(PROModelControllerTransformationLog *)log {
    if (![log isKindOfClass:[PROModelControllerTransformationLog class]])
        return NO;

    if (!NSEqualObjects(self.modelController, log.modelController))
        return NO;

    return [super isEqual:log];
}

@end
