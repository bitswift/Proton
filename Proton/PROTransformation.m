//
//  PROTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 12.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROTransformation.h"
#import "PROModelController.h"

NSString * const PROTransformationNewValueForKeyPathBlockKey = @"PROTransformationNewValueForKeyPathBlock";
NSString * const PROTransformationMutableArrayForKeyPathBlockKey = @"PROTransformationMutableArrayForKeyPathBlock";
NSString * const PROTransformationWrappedValueForKeyPathBlockKey = @"PROTransformationWrappedValueForKeyPathBlock";
NSString * const PROTransformationBlocksForIndexAtKeyPathBlockKey = @"PROTransformationBlocksForIndexAtKeyPathBlock";

NSString * const PROTransformationFailingTransformationsErrorKey = @"PROTransformationFailingTransformations";
NSString * const PROTransformationFailingTransformationPathErrorKey = @"PROTransformationFailingTransformationPath";

const NSInteger PROTransformationErrorIndexOutOfBounds = 1;
const NSInteger PROTransformationErrorMismatchedInput = 2;
const NSInteger PROTransformationErrorUnsupportedInputType = 3;

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

- (BOOL)transformInPlace:(id *)objPtr error:(NSError **)error; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return NO;
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result; {
    return [self applyBlocks:blocks transformationResult:result keyPath:nil];
}

- (BOOL)applyBlocks:(NSDictionary *)blocks transformationResult:(id)result keyPath:(NSString *)keyPath; {
    NSAssert(NO, @"%s should be implemented by a concrete subclass", __func__);
    return NO;
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSAssert1(NO, @"%s should be implemented by a concrete subclass", __func__);
    return NO;
}

#pragma mark Error Handling

+ (NSString *)errorDomain {
    return @"com.bitswift.Proton.PROTransformationErrorDomain";
}

- (NSError *)errorWithCode:(NSInteger)code format:(NSString *)format, ...; {
    NSParameterAssert(format != nil);

    va_list args;
    va_start(args, format);

    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        description, NSLocalizedDescriptionKey,
        [NSArray arrayWithObject:self], PROTransformationFailingTransformationsErrorKey,
        @"", PROTransformationFailingTransformationPathErrorKey,
        nil
    ];

    return [NSError
        errorWithDomain:[[self class] errorDomain]
        code:code
        userInfo:userInfo
    ];
}

- (NSError *)prependTransformationPath:(NSString *)transformationPath toError:(NSError *)error; {
    NSParameterAssert(transformationPath != nil);

    if (!error)
        return nil;

    NSMutableDictionary *userInfo = [error.userInfo mutableCopy];

    NSMutableArray *transformations = [[userInfo objectForKey:PROTransformationFailingTransformationsErrorKey] mutableCopy];
    [transformations insertObject:self atIndex:0];
    [userInfo setObject:transformations forKey:PROTransformationFailingTransformationsErrorKey];

    NSString *path = [transformationPath stringByAppendingString:[userInfo objectForKey:PROTransformationFailingTransformationPathErrorKey]];
    [userInfo setObject:path forKey:PROTransformationFailingTransformationPathErrorKey];

    return [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
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
