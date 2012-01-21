//
//  PROTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROTransformation.h>
#import <Proton/PROModelController.h>

NSString * const PROTransformationFailingTransformationsErrorKey = @"FailingTransformations";
NSString * const PROTransformationFailingTransformationPathErrorKey = @"FailingTransformationPath";

NSInteger PROTransformationErrorIndexOutOfBounds = 1;
NSInteger PROTransformationErrorMismatchedInput = 2;
NSInteger PROTransformationErrorUnsupportedInputType = 3;

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

- (id)transform:(id)obj error:(NSError **)error; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return nil;
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return NO;
}

#pragma mark Error Handling

+ (NSString *)errorDomain {
    return @"PROTransformationErrorDomain";
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
