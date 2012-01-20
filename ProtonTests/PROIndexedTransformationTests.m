//
//  PROIndexedTransformationTests.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROIndexedTransformationTests.h"
#import <Proton/PROUniqueTransformation.h>
#import <Proton/PROIndexedTransformation.h>

@interface PROIndexedTransformationTests ()
@property (nonatomic, copy, readonly) NSArray *startValue;
@property (nonatomic, copy, readonly) NSArray *endValue;

@property (nonatomic, copy, readonly) NSArray *transformations;
@property (nonatomic, copy, readonly) NSIndexSet *indexes;
@end

@implementation PROIndexedTransformationTests

- (NSArray *)startValue {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithInt:5],
        [NSNumber numberWithInt:5],
        @"foo",
        nil
    ];
}

- (NSArray *)endValue {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithBool:NO],
        [NSNumber numberWithInt:5],
        @"bar",
        nil
    ];
}

- (NSArray *)transformations {
    NSMutableArray *transformations = [[NSMutableArray alloc] init];

    {
        // array[1] = 5 -> NO

        id inputValue = [NSNumber numberWithInt:5];
        id outputValue = [NSNumber numberWithBool:NO];
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:inputValue outputValue:outputValue];

        [transformations addObject:transformation];
    }

    {
        // array[3] = "foo" -> "bar"

        id inputValue = @"foo";
        id outputValue = @"bar";
        PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:inputValue outputValue:outputValue];

        [transformations addObject:transformation];
    }

    return transformations;
}

- (NSIndexSet *)indexes {
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    [indexes addIndex:1];
    [indexes addIndex:3];

    return indexes;
}

- (void)testInitialization {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] init];
    STAssertNotNil(transformation, @"");

    STAssertNil(transformation.indexes, @"");

    // an indexed transformation without a transformation should have an empty
    // 'transformations' array (it should not be 'nil', since the class supports
    // children)
    STAssertEqualObjects(transformation.transformations, [NSArray array], @"");
}

- (void)testInitializationWithTransformation {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];
    STAssertNotNil(indexedTransformation, @"");

    STAssertEqualObjects(indexedTransformation.indexes, self.indexes, @"");
    STAssertEqualObjects(indexedTransformation.transformations, self.transformations, @"");
}

- (void)testSingularInitialization {
   PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndex:1 transformation:[self.transformations objectAtIndex:0]];
   STAssertNotNil(indexedTransformation, @"");

   STAssertEqualObjects(indexedTransformation.indexes, [NSIndexSet indexSetWithIndex:1], @"");
   STAssertEqualObjects(indexedTransformation.transformations, [NSArray arrayWithObject:[self.transformations objectAtIndex:0]], @"");
}

- (void)testTransformationInBounds {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([indexedTransformation transform:self.startValue error:NULL], self.endValue, @"");

    STAssertNil([indexedTransformation transform:self.endValue error:NULL], @"");
    STAssertNil([indexedTransformation transform:[NSArray array] error:NULL], @"");
}

- (void)testTransformationOutOfBounds {
    NSIndexSet *outOfBoundsSet = [NSIndexSet indexSetWithIndex:50000];
    NSArray *transformations = [NSArray arrayWithObject:[self.transformations objectAtIndex:0]];

    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:outOfBoundsSet transformations:transformations];

    // an out of bounds index should return nil
    NSError *error = nil;
    STAssertNil([indexedTransformation transform:self.startValue error:&error], @"");

    STAssertEquals(error.code, PROTransformationErrorIndexOutOfBounds, @"");
    STAssertNotNil(error.localizedDescription, @"");

    NSArray *failingTransformations = [[NSArray arrayWithObject:indexedTransformation] arrayByAddingObjectsFromArray:transformations];
    STAssertEqualObjects([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey], failingTransformations, @"");

    STAssertNil([indexedTransformation transform:self.endValue error:NULL], @"");
    STAssertNil([indexedTransformation transform:[NSArray array] error:NULL], @"");
}

- (void)testPassthroughTransformation {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue error:NULL], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue error:NULL], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSArray array] error:NULL], [NSArray array], @"");
}

- (void)testReverseTransformation {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    PROIndexedTransformation *reverseTransformation = (id)[transformation reverseTransformation];
    STAssertNotNil(reverseTransformation, @"");

    // indexes should stay the same
    STAssertEqualObjects(transformation.indexes, reverseTransformation.indexes, @"");

    [transformation.transformations enumerateObjectsUsingBlock:^(PROTransformation *transformationAtIndex, NSUInteger index, BOOL *stop){
        // the reverse transformation of this sub-transformation should be the
        // object at the same index of our reverse transformation
        STAssertEqualObjects(transformationAtIndex.reverseTransformation, [reverseTransformation.transformations objectAtIndex:index], @"");
    }];

    // for the reverse transformation, giving the endValue should yield the
    // startValue
    STAssertEqualObjects([reverseTransformation transform:self.endValue error:NULL], self.startValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.startValue error:NULL], @"");
    STAssertNil([reverseTransformation transform:[NSArray array] error:NULL], @"");
}

- (void)testEquality {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    PROIndexedTransformation *equalTransformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROIndexedTransformation *inequalTransformation = [[PROIndexedTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROIndexedTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];
    PROIndexedTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

@end
