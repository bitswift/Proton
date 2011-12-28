//
//  PROTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROTransformation.h>

@implementation PROTransformation

#pragma mark Properties

- (PROTransformation *)reverseTransformation; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return self;
}

- (NSArray *)transformations {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return nil;
}

#pragma mark Transformation

- (id)transform:(id)obj {
    PROTransformationBlock block = [self transformationBlockUsingRewriterBlock:nil];
    return block(obj);
}

- (PROTransformationBlock)transformationBlockUsingRewriterBlock:(PROTransformationRewriterBlock)block; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return nil;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

@end
