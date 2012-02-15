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
#import "PROTransformationLogEntry.h"

@implementation PROMutableModelTransformationResultInfo

#pragma mark Properties

@synthesize mutableModelsByKey = m_mutableModelsByKey;
@synthesize logEntriesByMutableModel = m_logEntriesByMutableModel;

- (void)setLogEntries:(NSArray *)logEntries forMutableModels:(NSArray *)mutableModels; {
    NSParameterAssert(logEntries.count == mutableModels.count);

    NSUInteger count = logEntries.count;
    if (!count) {
        m_logEntriesByMutableModel = nil;
        return;
    }

    CFRange fullRange = CFRangeMake(0, (CFIndex)count);

    const void **keys = malloc(sizeof(*keys) * count);
    if (!PROAssert(keys, @"Could not allocate space for %lu dictionary keys", (unsigned long)count))
        return;

    @onExit {
        free(keys);
    };

    CFArrayGetValues((__bridge CFArrayRef)mutableModels, fullRange, keys);

    const void **values = malloc(sizeof(*values) * count);
    if (!PROAssert(values, @"Could not allocate space for %lu dictionary values", (unsigned long)count))
        return;

    @onExit {
        free(values);
    };

    CFArrayGetValues((__bridge CFArrayRef)logEntries, fullRange, values);

    CFDictionaryRef logEntriesByMutableModel = CFDictionaryCreate(
        NULL,
        keys,
        values,
        (CFIndex)count,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    m_logEntriesByMutableModel = (__bridge_transfer id)logEntriesByMutableModel;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (!self)
        return nil;

    self.mutableModelsByKey = [coder decodeObjectForKey:PROKeyForObject(self, mutableModelsByKey)];
    
    NSArray *logEntries = [coder decodeObjectForKey:@"logEntries"];
    NSArray *mutableModels = [coder decodeObjectForKey:@"mutableModels"];

    if (logEntries.count == mutableModels.count)
        [self setLogEntries:logEntries forMutableModels:mutableModels];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.mutableModelsByKey)
        [coder encodeObject:self.mutableModelsByKey forKey:PROKeyForObject(self, mutableModelsByKey)];

    if (self.logEntriesByMutableModel) {
        NSArray *mutableModels = self.logEntriesByMutableModel.allKeys;
        [coder encodeObject:mutableModels forKey:@"mutableModels"];

        NSArray *logEntries = [self.logEntriesByMutableModel objectsForKeys:mutableModels notFoundMarker:[NSNull null]];
        [coder encodeObject:logEntries forKey:@"logEntries"];
    }
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PROMutableModelTransformationResultInfo *info = [[[self class] allocWithZone:zone] init];

    info.mutableModelsByKey = self.mutableModelsByKey;

    // this depends on the underlying CFDictionary being immutable -- i'm afraid
    // to call -copy here, since NSDictionary might screw with the callbacks for our keys
    info->m_logEntriesByMutableModel = m_logEntriesByMutableModel;

    return info;
}

#pragma mark NSObject overrides

- (NSString *)description {
    NSString *(^modelDescription)(PROMutableModel *) = ^(PROMutableModel *model){
        PROTransformationLogEntry *logEntry = [self.logEntriesByMutableModel objectForKey:model];
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
    // hashes should not change even if the data mutates, so only use immutable
    // data
    return self.logEntriesByMutableModel.allValues.hash;
}

- (BOOL)isEqual:(PROMutableModelTransformationResultInfo *)info {
    if (![info isKindOfClass:[PROMutableModelTransformationResultInfo class]])
        return NO;

    if (!NSEqualObjects(self.mutableModelsByKey, info.mutableModelsByKey))
        return NO;

    if (!NSEqualObjects(self.logEntriesByMutableModel, info.logEntriesByMutableModel))
        return NO;

    return YES;
}

@end
