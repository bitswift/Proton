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
#import "PROMutableModelTransformationResultInfo.h"

@implementation PROMutableModelTransformationLog

#pragma mark Properties

@synthesize transformationResultInfoByLogEntry = m_transformationResultInfoByLogEntry;

- (NSMutableDictionary *)transformationResultInfoByLogEntry {
    if (!m_transformationResultInfoByLogEntry) {
        m_transformationResultInfoByLogEntry = [NSMutableDictionary dictionary];
    }

    return m_transformationResultInfoByLogEntry;
}

#pragma mark Log Entries

- (void)removeLogEntry:(PROTransformationLogEntry *)logEntry; {
    [super removeLogEntry:logEntry];
    [self.transformationResultInfoByLogEntry removeObjectForKey:logEntry];
}

- (PROTransformationLogEntry *)logEntryWithMutableModel:(PROMutableModel *)mutableModel childLogEntry:(PROTransformationLogEntry *)childLogEntry; {
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
}

#pragma mark NSObject overrides

- (BOOL)isEqual:(PROMutableModelTransformationLog *)log {
    if (![log isKindOfClass:[PROMutableModelTransformationLog class]])
        return NO;

    if (![super isEqual:log])
        return NO;

    if (!NSEqualObjects(self.transformationResultInfoByLogEntry, log.transformationResultInfoByLogEntry))
        return NO;

    return YES;
}

@end
