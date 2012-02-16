//
//  PROMutableModelTransformationLog.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModelTransformationLog.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"
#import "PROMutableModel.h"
#import "PROMutableModelTransformationLogEntry.h"
#import "PROMutableModelTransformationResultInfo.h"

@implementation PROMutableModelTransformationLog

#pragma mark Properties

// implemented by <PROTransformationLog>
@dynamic latestLogEntry;

@synthesize transformationResultInfoByLogEntry = m_transformationResultInfoByLogEntry;
@synthesize mutableModel = m_mutableModel;

- (NSMutableDictionary *)transformationResultInfoByLogEntry {
    if (!m_transformationResultInfoByLogEntry) {
        m_transformationResultInfoByLogEntry = [NSMutableDictionary dictionary];
    }

    return m_transformationResultInfoByLogEntry;
}

#pragma mark Initialization

- (id)initWithMutableModel:(PROMutableModel *)mutableModel; {
    NSParameterAssert(mutableModel != nil);

    PROMutableModelTransformationLogEntry *logEntry = [[PROMutableModelTransformationLogEntry alloc]
        initWithParentLogEntry:nil
        mutableModelUniqueIdentifier:mutableModel.uniqueIdentifier
    ];

    self = [self initWithLogEntry:logEntry];
    if (!self)
        return nil;

    m_mutableModel = mutableModel;
    return self;
}

#pragma mark Log Entries

- (PROTransformationLogEntry *)logEntryWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry; {
    return [[PROMutableModelTransformationLogEntry alloc]
        initWithParentLogEntry:parentLogEntry
        mutableModelUniqueIdentifier:self.mutableModel.uniqueIdentifier
    ];
}

- (void)removeLogEntry:(PROTransformationLogEntry *)logEntry; {
    [super removeLogEntry:logEntry];
    [self.transformationResultInfoByLogEntry removeObjectForKey:logEntry];
}

- (PROMutableModelTransformationLogEntry *)logEntryWithMutableModel:(PROMutableModel *)mutableModel childLogEntry:(PROMutableModelTransformationLogEntry *)childLogEntry; {
    NSParameterAssert(mutableModel != nil);
    NSParameterAssert(childLogEntry != nil);

    // using the ivar to avoid automatically instantiating this dictionary
    return [m_transformationResultInfoByLogEntry keyOfEntryPassingTest:^ BOOL (PROTransformationLogEntry *testLogEntry, PROMutableModelTransformationResultInfo *resultInfo, BOOL *stop){
        return [[resultInfo.logEntriesByMutableModel objectForKey:mutableModel] isEqual:childLogEntry];
    }];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    m_transformationResultInfoByLogEntry = [[coder decodeObjectForKey:PROKeyForObject(self, transformationResultInfoByLogEntry)] mutableCopy];
    m_mutableModel = [coder decodeObjectForKey:PROKeyForObject(self, mutableModel)];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    NSOrderedSet *archivableEntries = self.archivableLogEntries;
    NSDictionary *limitedResultInfo = [self.transformationResultInfoByLogEntry filterEntriesUsingBlock:^(PROTransformationLogEntry *entry, id resultInfo){
        return [archivableEntries containsObject:entry];
    }];

    if (limitedResultInfo)
        [coder encodeObject:limitedResultInfo forKey:PROKeyForObject(self, transformationResultInfoByLogEntry)];

    if (self.mutableModel)
        [coder encodeConditionalObject:self.mutableModel forKey:PROKeyForObject(self, mutableModel)];
}

#pragma mark NSObject overrides

- (BOOL)isEqual:(PROMutableModelTransformationLog *)log {
    if (![log isKindOfClass:[PROMutableModelTransformationLog class]])
        return NO;

    if (![super isEqual:log])
        return NO;

    if (!NSEqualObjects(self.mutableModel, log.mutableModel))
        return NO;

    if (!NSEqualObjects(self.transformationResultInfoByLogEntry, log.transformationResultInfoByLogEntry))
        return NO;

    return YES;
}

@end
