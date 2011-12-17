//
//  PROUniqueIdentifier.m
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROUniqueIdentifier.h"

@implementation PROUniqueIdentifier

#pragma mark Lifecycle

- (id)init {
    return [self initWithString:nil];
}

- (id)initWithString:(NSString *)uuidString {
    return nil;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // We're immutable
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
}

- (NSString *)stringValue {
    return nil;
}

@end
