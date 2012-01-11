//
//  PROUniqueIdentifier.m
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROUniqueIdentifier.h"

@interface PROUniqueIdentifier () {
    CFUUIDRef m_uuid;
}
@end

@implementation PROUniqueIdentifier

#pragma mark Lifecycle

- (void)dealloc {
    if (m_uuid)
        CFRelease(m_uuid);
}

- (id)init {
    return [self initWithString:nil];
}

- (id)initWithString:(NSString *)uuidString {
    self = [super init];
    if (!self)
        return nil;

    if (uuidString) {
        m_uuid = CFUUIDCreateFromString(NULL, (__bridge CFStringRef)uuidString);
    } else {
        m_uuid = CFUUIDCreate(NULL);
    }

    if (!m_uuid)
        return nil;

    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // We're immutable
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSString *uuidString = [aDecoder decodeObjectForKey:@"stringValue"];
    if (!uuidString)
        return nil;

    return [self initWithString:uuidString];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    NSString *stringValue = self.stringValue;
    if (stringValue)
        [aCoder encodeObject:stringValue forKey:@"stringValue"];
}

#pragma mark Equality

- (NSUInteger)hash {
    // CFUUIDRefs are uniqued
    return (NSUInteger)m_uuid;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[PROUniqueIdentifier class]])
        return NO;

    PROUniqueIdentifier *other = object;
    // CFUUIDRefs are uniqued, so pointer equality is equivalent to value equality
    return (m_uuid == other->m_uuid);
}

#pragma mark Properties

- (NSString *)stringValue {
    return (__bridge_transfer NSString *)CFUUIDCreateString(NULL, m_uuid);
}

#pragma mark Debugging

- (NSString *)description {
    return [NSString stringWithFormat:@"UID(%@)", self.stringValue];
}

@end
