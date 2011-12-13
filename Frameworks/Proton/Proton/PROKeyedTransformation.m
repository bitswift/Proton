//
//  PROKeyedTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROKeyedTransformation.h>

@implementation PROKeyedTransformation

#pragma mark Properties

@synthesize valueTransformations = m_valueTransformations;

#pragma mark Lifecycle

- (id)init; {
    return [self initWithValueTransformations:nil];
}

- (id)initWithValueTransformations:(NSDictionary *)valueTransformations; {
    // TODO
    return nil;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    // TODO
    return obj;
}

- (PROTransformation *)reverseTransformation; {
    // TODO
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    // TODO
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    // TODO
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

@end
