//
//  PRORemovalTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PRORemovalTransformationTests.h"
#import <Proton/EXTNil.h>
#import <Proton/PROInsertionTransformation.h>
#import <Proton/PRORemovalTransformation.h>

@interface PRORemovalTransformationTests ()
@property (nonatomic, copy, readonly) NSArray *startValue;
@property (nonatomic, copy, readonly) NSArray *endValue;

@property (nonatomic, copy, readonly) NSArray *objects;
@property (nonatomic, copy, readonly) NSIndexSet *indexes;
@end

@implementation PRORemovalTransformationTests

- (NSArray *)startValue {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithBool:NO],
        [NSNumber numberWithInt:5],
        @"foo",
        @"bar",
        nil
    ];
}

- (NSArray *)endValue {
    return [NSArray arrayWithObjects:
        [NSNumber numberWithInt:5],
        @"foo",
        nil
    ];
}

- (NSArray *)objects {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithBool:NO],
        @"bar",
        nil
    ];
}

- (NSIndexSet *)indexes {
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    // remove(array[0], null)
    [indexes addIndex:0];

    // remove(array[1], NO)
    [indexes addIndex:1];

    // remove(array[4], "bar")
    [indexes addIndex:4];

    return indexes;
}

- (void)testInitialization {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] init];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertNil(transformation.removalIndexes, @"");
    STAssertNil(transformation.expectedObjects, @"");
}

- (void)testInitializationWithObjects {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertEqualObjects(transformation.removalIndexes, self.indexes, @"");
    STAssertEqualObjects(transformation.expectedObjects, self.objects, @"");
}

- (void)testSingularInitialization {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:1 expectedObject:[NSNumber numberWithInt:5]];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertEqualObjects(transformation.removalIndexes, [NSIndexSet indexSetWithIndex:1], @"");
    STAssertEqualObjects(transformation.expectedObjects, [NSArray arrayWithObject:[NSNumber numberWithInt:5]], @"");
}

- (void)testTransformationInBounds {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([transformation transform:self.startValue error:NULL], self.endValue, @"");

    STAssertNil([transformation transform:self.endValue error:NULL], @"");
    STAssertNil([transformation transform:[NSArray array] error:NULL], @"");
}

- (void)testTransformationOutOfBounds {
    NSIndexSet *outOfBoundsSet = [NSIndexSet indexSetWithIndex:50000];
    NSArray *objects = [NSArray arrayWithObject:[self.objects objectAtIndex:0]];

    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:outOfBoundsSet expectedObjects:objects];

    // an out of bounds index should return nil
    NSError *error = nil;
    STAssertNil([transformation transform:self.startValue error:&error], @"");

    STAssertEquals(error.code, PROTransformationErrorIndexOutOfBounds, @"");
    STAssertNotNil(error.localizedDescription, @"");

    NSArray *failingTransformations = [NSArray arrayWithObject:transformation];
    STAssertEqualObjects([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey], failingTransformations, @"");

    STAssertNil([transformation transform:self.endValue error:NULL], @"");
    STAssertNil([transformation transform:[NSArray array] error:NULL], @"");
}

- (void)testTransformationInvalidObjects {
    NSUInteger count = [self.objects count];
    NSMutableArray *invalidObjects = [[NSMutableArray alloc] initWithCapacity:count];

    // fill this array with nulls
    for (NSUInteger i = 0;i < count;++i) {
        [invalidObjects addObject:[NSNull null]];
    }

    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:invalidObjects];

    // invalid objects should return nil
    NSError *error = nil;
    STAssertNil([transformation transform:self.startValue error:&error], @"");

    STAssertEquals(error.code, PROTransformationErrorMismatchedInput, @"");
    STAssertNotNil(error.localizedDescription, @"");

    NSArray *failingTransformations = [NSArray arrayWithObject:transformation];
    STAssertEqualObjects([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey], failingTransformations, @"");

    STAssertNil([transformation transform:self.endValue error:NULL], @"");
    STAssertNil([transformation transform:[NSArray array] error:NULL], @"");
}

- (void)testTransformationResultingInEmptyArray {
    NSArray *objects = [NSArray arrayWithObjects:@"foobar", [NSNumber numberWithInt:5], [NSNull null], nil];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [objects count])];

    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexSet expectedObjects:objects];
    STAssertEqualObjects([transformation transform:objects error:NULL], [NSArray array], @"");
}

- (void)testPassthroughTransformation {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue error:NULL], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue error:NULL], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSArray array] error:NULL], [NSArray array], @"");
}

- (void)testReverseTransformation {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    PROInsertionTransformation *reverseTransformation = (id)[transformation reverseTransformation];
    STAssertNotNil(reverseTransformation, @"");

    // the reverse of a removal is an insertion
    STAssertTrue([reverseTransformation isKindOfClass:[PROInsertionTransformation class]], @"");

    // indexes and objects should be the same
    STAssertEqualObjects(transformation.removalIndexes, reverseTransformation.insertionIndexes, @"");
    STAssertEqualObjects(transformation.expectedObjects, reverseTransformation.objects, @"");

    // for the reverse transformation, giving the endValue should yield the
    // startValue
    STAssertEqualObjects([reverseTransformation transform:self.endValue error:NULL], self.startValue, @"");

    STAssertNil([reverseTransformation transform:[NSArray array] error:NULL], @"");
}

- (void)testEquality {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    PRORemovalTransformation *equalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PRORemovalTransformation *inequalTransformation = [[PRORemovalTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PRORemovalTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];
    PRORemovalTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

@end
