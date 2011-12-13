//
//  PROUniqueTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROUniqueTransformation.h>

@implementation PROUniqueTransformation

#pragma mark Properties

@synthesize inputValue = m_inputValue;
@synthesize outputValue = m_outputValue;

#pragma mark Lifecycle

- (id)init; {
    return [self initWithInputValue:nil outputValue:nil];
}

- (id)initWithInputValue:(id)inputValue outputValue:(id)outputValue; {
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
