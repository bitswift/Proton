//
//  PROMutableModelTransformationLogEntry.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModelTransformationLogEntry.h"
#import "PROKeyValueCodingMacros.h"
#import "PROUniqueIdentifier.h"

@implementation PROMutableModelTransformationLogEntry

#pragma mark Properties

@synthesize mutableModelUniqueIdentifier = m_mutableModelUniqueIdentifier;

#pragma mark Initialization

- (id)initWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry mutableModelUniqueIdentifier:(PROUniqueIdentifier *)mutableModelUniqueIdentifier; {
    self = [self initWithParentLogEntry:parentLogEntry];
    if (!self)
        return nil;

    m_mutableModelUniqueIdentifier = [mutableModelUniqueIdentifier copy];
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROUniqueIdentifier *mutableModelIdentifier = [coder decodeObjectForKey:PROKeyForObject(self, mutableModelUniqueIdentifier)];
    if (!mutableModelIdentifier)
        return nil;

    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    m_mutableModelUniqueIdentifier = [mutableModelIdentifier copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    if (self.mutableModelUniqueIdentifier)
        [coder encodeObject:self.mutableModelUniqueIdentifier forKey:PROKeyForObject(self, mutableModelUniqueIdentifier)];
}

@end
