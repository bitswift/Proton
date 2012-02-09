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

@implementation PROModelControllerTransformationLogEntry

#pragma mark Properties

@dynamic parentLogEntry;

@synthesize modelControllerIdentifier = m_modelControllerIdentifier;

#pragma mark Initialization

- (id)initWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry modelControllerIdentifier:(PROUniqueIdentifier *)modelControllerIdentifier; {
    self = [self initWithParentLogEntry:parentLogEntry];
    if (!self)
        return nil;

    m_modelControllerIdentifier = [modelControllerIdentifier copy];
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    m_modelControllerIdentifier = [coder decodeObjectForKey:PROKeyForObject(self, modelControllerIdentifier)];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    if (self.modelControllerIdentifier)
        [coder encodeObject:self.modelControllerIdentifier forKey:PROKeyForObject(self, modelControllerIdentifier)];
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

    return YES;
}

@end
