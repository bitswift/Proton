//
//  PROMutableModelTransformationResultInfo.m
//  Proton
//
//  Created by Justin Spahr-Summers on 14.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModelTransformationResultInfo.h"
#import "EXTScope.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"
#import "PROMutableModel.h"
#import "PROMutableModelTransformationLogEntry.h"

@implementation PROMutableModelTransformationResultInfo

#pragma mark Properties

@synthesize mutableModelsByKey = m_mutableModelsByKey;
@synthesize logEntriesByMutableModelUniqueIdentifier = m_logEntriesByMutableModelUniqueIdentifier;

- (void)setMutableModelsByKey:(NSDictionary *)modelsByKey {
    if (modelsByKey == m_mutableModelsByKey)
        return;

    m_mutableModelsByKey = [modelsByKey mapValuesUsingBlock:^(NSString *key, id value){
        if (![value isKindOfClass:[PROMutableModel class]]) {
            // assume this is a collection which needs to be copied
            return [value copy];
        } else {
            return value;
        }
    }];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (!self)
        return nil;

    self.mutableModelsByKey = [coder decodeObjectForKey:PROKeyForObject(self, mutableModelsByKey)];
    self.logEntriesByMutableModelUniqueIdentifier = [coder decodeObjectForKey:PROKeyForObject(self, logEntriesByMutableModelUniqueIdentifier)];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.mutableModelsByKey)
        [coder encodeObject:self.mutableModelsByKey forKey:PROKeyForObject(self, mutableModelsByKey)];

    if (self.logEntriesByMutableModelUniqueIdentifier)
        [coder encodeObject:self.logEntriesByMutableModelUniqueIdentifier forKey:PROKeyForObject(self, logEntriesByMutableModelUniqueIdentifier)];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PROMutableModelTransformationResultInfo *info = [[[self class] allocWithZone:zone] init];

    info.mutableModelsByKey = self.mutableModelsByKey;
    info.logEntriesByMutableModelUniqueIdentifier = self.logEntriesByMutableModelUniqueIdentifier;

    return info;
}

#pragma mark NSObject overrides

- (NSString *)description {
    NSString *(^modelDescription)(PROMutableModel *) = ^(PROMutableModel *model){
        PROTransformationLogEntry *logEntry = [self.logEntriesByMutableModelUniqueIdentifier objectForKey:model.uniqueIdentifier];
        return [NSString stringWithFormat:@"<%@: %p> = %@", [model class], (__bridge void *)model, logEntry];
    };

    NSDictionary *stringsByKey = [self.mutableModelsByKey mapValuesUsingBlock:^(NSString *key, id obj){
        if ([obj isKindOfClass:[NSArray class]]) {
            NSArray *modelDescriptions = [obj mapUsingBlock:^(PROMutableModel *model){
                return modelDescription(model);
            }];

            return modelDescriptions.description;
        } else if ([obj isKindOfClass:[PROMutableModel class]]) {
            return modelDescription(obj);
        } else {
            return [obj description];
        }
    }];

    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], (__bridge void *)self, stringsByKey];
}

- (NSUInteger)hash {
    return self.logEntriesByMutableModelUniqueIdentifier.hash;
}

- (BOOL)isEqual:(PROMutableModelTransformationResultInfo *)info {
    if (![info isKindOfClass:[PROMutableModelTransformationResultInfo class]])
        return NO;

    if (!NSEqualObjects(self.mutableModelsByKey, info.mutableModelsByKey))
        return NO;

    if (!NSEqualObjects(self.logEntriesByMutableModelUniqueIdentifier, info.logEntriesByMutableModelUniqueIdentifier))
        return NO;

    return YES;
}

@end
