//
//  PROTransformationLogEntry.m
//  Proton
//
//  Created by Justin Spahr-Summers on 02.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROTransformationLogEntry.h"
#import "NSObject+ComparisonAdditions.h"
#import "PROKeyValueCodingMacros.h"
#import "PROUniqueIdentifier.h"

@implementation PROTransformationLogEntry

#pragma mark Properties

@synthesize uniqueIdentifier = m_uniqueIdentifier;
@synthesize parentLogEntry = m_parentLogEntry;

#pragma mark Initialization

- (id)init; {
    return [self initWithParentLogEntry:nil];
}

- (id)initWithParentLogEntry:(PROTransformationLogEntry *)parentLogEntry; {
    self = [super init];
    if (!self)
        return nil;

    m_uniqueIdentifier = [[PROUniqueIdentifier alloc] init];
    m_parentLogEntry = parentLogEntry;

    return self;
}

#pragma mark Log Entry Tree

- (BOOL)isDescendantOfLogEntry:(PROTransformationLogEntry *)ancestorLogEntry; {
    NSParameterAssert(ancestorLogEntry != nil);

    if ([self isEqual:ancestorLogEntry])
        return YES;

    return [self.parentLogEntry isDescendantOfLogEntry:ancestorLogEntry];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROUniqueIdentifier *identifier = [coder decodeObjectForKey:PROKeyForObject(self, uniqueIdentifier)];
    if (!identifier)
        return nil;

    PROTransformationLogEntry *parent = [coder decodeObjectForKey:PROKeyForObject(self, parentLogEntry)];

    self = [self initWithParentLogEntry:parent];
    if (!self)
        return nil;

    m_uniqueIdentifier = [identifier copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.uniqueIdentifier forKey:PROKeyForObject(self, uniqueIdentifier)];

    if (self.parentLogEntry)
        [coder encodeObject:self.parentLogEntry forKey:PROKeyForObject(self, parentLogEntry)];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p ID: %@>", [self class], (__bridge void *)self, self.uniqueIdentifier];
}

- (NSUInteger)hash {
    return self.uniqueIdentifier.hash;
}

- (BOOL)isEqual:(PROTransformationLogEntry *)entry {
    if (![entry isKindOfClass:[PROTransformationLogEntry class]])
        return NO;

    return [self.uniqueIdentifier isEqual:entry.uniqueIdentifier];
}

@end
