//
//  PROKeyedTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROKeyedTransformationTests.h"
#import <Proton/Proton.h>

@interface PROKeyedTransformationTests ()
@property (nonatomic, copy, readonly) NSDictionary *startValue;
@property (nonatomic, copy, readonly) NSDictionary *transformations;
@property (nonatomic, copy, readonly) NSDictionary *endValue;
@end

@implementation PROKeyedTransformationTests

- (NSDictionary *)startValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        [NSNull null], @"nil",
        [NSNumber numberWithBool:YES], @"5",
        nil
    ];
}

- (NSDictionary *)transformations {
    NSMutableDictionary *transformations = [[NSMutableDictionary alloc] init];
    
    {
        // for key "nil": NSNull -> EXTNil
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSNull null] outputValue:[EXTNil null]];
        [transformations setObject:transformation forKey:@"nil"];
    }

    {
        // for key "5": YES -> NO
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSNumber numberWithBool:YES] outputValue:[NSNumber numberWithBool:NO]];
        [transformations setObject:transformation forKey:@"5"];
    }

    // key "foo" is left unmodified

    return transformations;
}

- (NSDictionary *)endValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        [EXTNil null], @"nil",
        [NSNumber numberWithBool:NO], @"5",
        nil
    ];
}

- (void)testInitialization {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] init];
    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.valueTransformations, @"");
}

- (void)testInitializationWithTransformations {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.valueTransformations, self.transformations, @"");
}

- (void)testMultipleTransformations {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([transformation transform:self.startValue], self.endValue, @"");

    // anything else should return nil
    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testPassthroughTransformation {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
}

- (void)testEquality {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];

    PROKeyedTransformation *equalTransformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROKeyedTransformation *inequalTransformation = [[PROKeyedTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROKeyedTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];
    PROKeyedTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

- (void)testReverseTransformation {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];

    PROKeyedTransformation *reverseTransformation = (id)transformation.reverseTransformation;

    // the transformations of the reverse transformation should be the same
    // keys, with the reversed transformations of each value
    
    NSMutableDictionary *reverseTransformations = [[NSMutableDictionary alloc] init];
    for (id key in self.transformations) {
        PROTransformation *t = [self.transformations objectForKey:key];
        [reverseTransformations setObject:t.reverseTransformation forKey:key];
    }

    STAssertEqualObjects(reverseTransformation.valueTransformations, reverseTransformations, @"");
    
    // for the reverse transformation, giving the endValue should yield the
    // startValue
    STAssertEqualObjects([reverseTransformation transform:self.endValue], self.startValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.startValue], @"");
    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testRewritingTransformations {
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];

    PROTransformationRewriterBlock rewriterBlock = ^ id (PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        id result = transformationBlock(obj);

        if (transformation == keyedTransformation) {
            NSMutableDictionary *modifiedResult = [result mutableCopy];
            [modifiedResult setObject:@"baz" forKey:@"foo"];

            result = modifiedResult;
        }

        return result;
    };

    PROTransformationBlock rewrittenBlock = [keyedTransformation rewrittenTransformationUsingBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    NSMutableDictionary *expectedEndValue = [self.endValue mutableCopy];
    [expectedEndValue setObject:@"baz" forKey:@"foo"];

    STAssertEqualObjects(rewrittenBlock(self.startValue), expectedEndValue, @"");
}

@end
