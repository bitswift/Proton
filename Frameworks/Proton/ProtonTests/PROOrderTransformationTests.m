//
//  PROOrderTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROOrderTransformationTests.h"
#import <Proton/PROOrderTransformation.h>

@interface PROOrderTransformationTests ()
@property (nonatomic, copy, readonly) NSIndexSet *singleStartIndexSet;
@property (nonatomic, copy, readonly) NSIndexSet *singleEndIndexSet;
@property (nonatomic, copy, readonly) NSArray *singleMovementStartValue;
@property (nonatomic, copy, readonly) NSArray *singleMovementEndValue;

@property (nonatomic, copy, readonly) NSIndexSet *multipleStartIndexSet;
@property (nonatomic, copy, readonly) NSIndexSet *multipleEndIndexSet;
@property (nonatomic, copy, readonly) NSArray *multipleMovementStartValue;
@property (nonatomic, copy, readonly) NSArray *multipleMovementEndValue;
@end

@implementation PROOrderTransformationTests

- (NSIndexSet *)singleStartIndexSet {
    return [NSIndexSet indexSetWithIndex:1];
}

- (NSIndexSet *)singleEndIndexSet {
    return [NSIndexSet indexSetWithIndex:3];
}

- (NSArray *)singleMovementStartValue {
    return [NSArray arrayWithObjects:
        @"foo",
        @"MOVEMENT",
        @"bar",
        @"buzz",
        @"baz",
        nil
    ];
}

- (NSArray *)singleMovementEndValue {
    return [NSArray arrayWithObjects:
        @"foo",
        @"bar",
        @"buzz",
        @"MOVEMENT",
        @"baz",
        nil
    ];
}

- (NSIndexSet *)multipleStartIndexSet {
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
    [indexSet addIndex:0];
    [indexSet addIndex:2];
    [indexSet addIndex:5];

    return indexSet;
}

- (NSIndexSet *)multipleEndIndexSet {
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(3, 3)];
}

- (NSArray *)multipleMovementStartValue {
    return [NSArray arrayWithObjects:
        @"foomove",
        @"bar",
        @"bazmove",
        @"buzz",
        @"blah",
        @"buzzmove",
        nil
    ];
}

- (NSArray *)multipleMovementEndValue {
    return [NSArray arrayWithObjects:
        @"bar",
        @"buzz",
        @"blah",
        @"foomove",
        @"bazmove",
        @"buzzmove",
        nil
    ];
}

- (void)testInitialization {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] init];
    STAssertNotNil(transformation, @"");

    // both index sets should be nil if not initialized with anything
    STAssertNil(transformation.startIndexes, @"");
    STAssertNil(transformation.endIndexes, @"");

    // an order transformation should not have any child transformations
    STAssertNil(transformation.transformations, @"");
}

- (void)testInitializationWithIndexSets {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.startIndexes, self.singleStartIndexSet, @"");
    STAssertEqualObjects(transformation.endIndexes, self.singleEndIndexSet, @"");

    // an order transformation should not have any child transformations
    STAssertNil(transformation.transformations, @"");
}

- (void)testReturningNil {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];

    // anything not an array should return 'nil'
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSNumber numberWithInt:5]], @"");
    STAssertNil([transformation transform:[NSSet set]], @"");

    // an array that's too small should return 'nil'
    STAssertNil([transformation transform:[NSArray array]], @"");
}

- (void)testSingleMovement {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];

    STAssertEqualObjects([transformation transform:self.singleMovementStartValue], self.singleMovementEndValue, @"");
}

- (void)testSingleIndexMovement {
    NSUInteger startIndex = [self.singleStartIndexSet firstIndex];
    NSUInteger endIndex = [self.singleEndIndexSet firstIndex];

    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndex:startIndex endIndex:endIndex];
    STAssertEqualObjects([transformation transform:self.singleMovementStartValue], self.singleMovementEndValue, @"");
}

- (void)testSingleMovementReverseTransformation {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];
    PROTransformation *reverseTransformation = transformation.reverseTransformation;

    // giving the end value should should yield the start value
    STAssertEqualObjects([reverseTransformation transform:self.singleMovementEndValue], self.singleMovementStartValue, @"");
}

- (void)testMultipleMovement {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.multipleStartIndexSet endIndexes:self.multipleEndIndexSet];

    STAssertEqualObjects([transformation transform:self.multipleMovementStartValue], self.multipleMovementEndValue, @"");
}

- (void)testMultipleMovementReverseTransformation {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.multipleStartIndexSet endIndexes:self.multipleEndIndexSet];
    PROTransformation *reverseTransformation = transformation.reverseTransformation;

    // giving the end value should should yield the start value
    STAssertEqualObjects([reverseTransformation transform:self.multipleMovementEndValue], self.multipleMovementStartValue, @"");
}

- (void)testEquality {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];

    PROOrderTransformation *equalTransformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROOrderTransformation *inequalTransformation = [[PROOrderTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROOrderTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROOrderTransformation *transformation = [[PROOrderTransformation alloc] initWithStartIndexes:self.singleStartIndexSet endIndexes:self.singleEndIndexSet];
    PROOrderTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

@end
