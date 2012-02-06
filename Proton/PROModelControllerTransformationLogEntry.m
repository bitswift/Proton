//
//  PROModelControllerTransformationLogEntry.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelControllerTransformationLogEntry.h"
#import "NSArray+HigherOrderAdditions.h"
#import "NSDictionary+HigherOrderAdditions.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROKeyValueCodingMacros.h"
#import "PROModelController.h"
#import "PROUniqueIdentifier.h"

@interface PROModelControllerTransformationLogEntry ()
@property (nonatomic, copy, readwrite) PROUniqueIdentifier *modelControllerIdentifier;
@property (nonatomic, copy, readwrite) NSDictionary *logEntriesByModelControllerKey;
@end

@implementation PROModelControllerTransformationLogEntry

#pragma mark Properties

@dynamic parentLogEntry;

@synthesize modelControllerIdentifier = m_modelControllerIdentifier;
@synthesize logEntriesByModelControllerKey = m_logEntriesByModelControllerKey;

#pragma mark Model Controller

- (void)captureModelController:(PROModelController *)modelController; {
    NSAssert(!self.modelControllerIdentifier, @"%s should not be invoked more than once", __func__);
    NSAssert(!self.logEntriesByModelControllerKey, @"%s should not be invoked more than once", __func__);

    self.modelControllerIdentifier = [modelController.uniqueIdentifier copy];

    NSDictionary *modelControllerKeys = [[modelController class] modelControllerKeysByModelKeyPath];
    if ([modelControllerKeys count]) {
        NSDictionary *modelControllerClasses = [[modelController class] modelControllerClassesByKey];

        self.logEntriesByModelControllerKey = [modelControllerClasses mapValuesUsingBlock:^ id (NSString *key, Class modelControllerClass){
            NSArray *controllers = [modelController valueForKey:key];
            if (![controllers count])
                return nil;

            return [controllers mapUsingBlock:^(PROModelController *controller){
                return [controller transformationLogEntryWithModelPointer:NULL];
            }];
        }];
    }
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    self.modelControllerIdentifier = [coder decodeObjectForKey:PROKeyForObject(self, modelControllerIdentifier)];
    self.logEntriesByModelControllerKey = [coder decodeObjectForKey:PROKeyForObject(self, logEntriesByModelControllerKey)];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    if (self.modelControllerIdentifier)
        [coder encodeObject:self.modelControllerIdentifier forKey:PROKeyForObject(self, modelControllerIdentifier)];

    if (self.logEntriesByModelControllerKey)
        [coder encodeObject:self.logEntriesByModelControllerKey forKey:PROKeyForObject(self, logEntriesByModelControllerKey)];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>( ID = %@, modelControllerID = %@ )", [self class], (__bridge void *)self, self.uniqueIdentifier, self.modelControllerIdentifier];
}

- (BOOL)isEqual:(PROModelControllerTransformationLogEntry *)entry {
    if (![entry isKindOfClass:[PROModelControllerTransformationLogEntry class]])
        return NO;

    if (![super isEqual:entry])
        return NO;

    if (!NSEqualObjects(self.modelControllerIdentifier, entry.modelControllerIdentifier))
        return NO;

    if (!NSEqualObjects(self.logEntriesByModelControllerKey, entry.logEntriesByModelControllerKey))
        return NO;

    return YES;
}

@end
