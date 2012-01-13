//
//  PROKeyedTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
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
        // for key "nil": NSNull -> @"null"
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSNull null] outputValue:@"null"];
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
        @"null", @"nil",
        [NSNumber numberWithBool:NO], @"5",
        nil
    ];
}

- (void)testInitialization {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] init];
    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.valueTransformations, @"");

    // a keyed transformation without value transformations should have an empty
    // 'transformations' array (it should not be 'nil', since the class supports
    // children)
    STAssertEqualObjects(transformation.transformations, [NSArray array], @"");
}

- (void)testSingularInitialization {
    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] init];
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKey:@"bar"];

    STAssertNotNil(transformation, @"");
    STAssertNotNil(transformation.valueTransformations, @"");
    STAssertEqualObjects(uniqueTransformation, [transformation.valueTransformations objectForKey:@"bar"], @"");
}

- (void)testInitializationWithTransformations {
    PROKeyedTransformation *transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:self.transformations];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.valueTransformations, self.transformations, @"");
    STAssertEqualObjects(transformation.transformations, [transformation.valueTransformations allValues], @"");
}

- (void)testInitializationWithKeyPath {
    NSDictionary *nestedStartValue = [NSDictionary dictionaryWithObject:@"bar" forKey:@"foo"];
    NSDictionary *nestedEndValue = [NSDictionary dictionaryWithObject:@"foo" forKey:@"foo"];

    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"bar" outputValue:@"foo"];

    NSDictionary *startValue = [NSDictionary dictionaryWithObject:nestedStartValue forKey:@"fizzbuzz"];
    NSDictionary *endValue = [NSDictionary dictionaryWithObject:nestedEndValue forKey:@"fizzbuzz"];

    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKeyPath:@"fizzbuzz.foo"];
    STAssertNotNil(keyedTransformation, @"");

    PROKeyedTransformation *expectedNestedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKey:@"foo"];
    STAssertEqualObjects([keyedTransformation.valueTransformations objectForKey:@"fizzbuzz"], expectedNestedTransformation, @"");
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

- (void)testTransformationOnEXTNil {
    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:[EXTNil null] outputValue:@"foo"];
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKey:@"someKey"];

    NSDictionary *expectedDictionary = [NSDictionary dictionaryWithObject:@"foo" forKey:@"someKey"];
    STAssertEqualObjects([keyedTransformation transform:[EXTNil null]], expectedDictionary, @"");
}

- (void)testTransformationRemovingEXTNilResults {
    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:[EXTNil null]];
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKey:@"someKey"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foo", @"someKey",
        [NSNumber numberWithInt:10], @"otherKey",
        nil
    ];

    NSDictionary *expectedDictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:10] forKey:@"otherKey"];

    STAssertEqualObjects([keyedTransformation transform:dictionary], expectedDictionary, @"");
}

- (void)testTransformationResultingInEmptyDictionary {
    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:[EXTNil null]];
    PROKeyedTransformation *keyedTransformation = [[PROKeyedTransformation alloc] initWithTransformation:uniqueTransformation forKey:@"someKey"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:@"foo" forKey:@"someKey"];
    STAssertEqualObjects([keyedTransformation transform:dictionary], [EXTNil null], @"");
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

@end
