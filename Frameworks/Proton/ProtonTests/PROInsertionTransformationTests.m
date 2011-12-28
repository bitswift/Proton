//
//  PROInsertionTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROInsertionTransformationTests.h"
#import <Proton/PROInsertionTransformation.h>
#import <Proton/PRORemovalTransformation.h>

@interface PROInsertionTransformationTests ()
@property (nonatomic, copy, readonly) NSArray *startValue;
@property (nonatomic, copy, readonly) NSArray *endValue;

@property (nonatomic, copy, readonly) NSArray *objects;
@property (nonatomic, copy, readonly) NSIndexSet *indexes;
@end

@implementation PROInsertionTransformationTests

- (NSArray *)startValue {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithInt:5],
        @"foo",
        nil
    ];
}

- (NSArray *)endValue {
    return [NSArray arrayWithObjects:
        [NSNull null],
        [NSNumber numberWithBool:NO],
        @"bar",
        [NSNumber numberWithInt:5],
        @"foo",
        nil
    ];
}

- (NSArray *)objects {
    return [NSArray arrayWithObjects:
        [NSNumber numberWithBool:NO],
        @"bar",
        nil
    ];
}

- (NSIndexSet *)indexes {
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    // insert(array[1], NO)
    [indexes addIndex:1];

    // insert(array[2], "bar")
    [indexes addIndex:2];

    return indexes;
}

- (void)testInitialization {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] init];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertNil(transformation.insertionIndexes, @"");
    STAssertNil(transformation.objects, @"");
}

- (void)testInitializationWithObjects {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertEqualObjects(transformation.insertionIndexes, self.indexes, @"");
    STAssertEqualObjects(transformation.objects, self.objects, @"");
}

- (void)testSingularInitialization {
    NSNumber *number = [NSNumber numberWithInt:5];
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:number];

    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformations, @"");

    STAssertEqualObjects(transformation.insertionIndexes, [NSIndexSet indexSetWithIndex:0], @"");
    STAssertEqualObjects(transformation.objects, [NSArray arrayWithObject:number], @"");
}

- (void)testTransformationInBounds {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([transformation transform:self.startValue], self.endValue, @"");

    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSArray array]], @"");
    STAssertNil([transformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testTransformationOutOfBounds {
    NSIndexSet *outOfBoundsSet = [NSIndexSet indexSetWithIndex:50000];
    NSArray *objects = [NSArray arrayWithObject:[self.objects objectAtIndex:0]];

    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:outOfBoundsSet objects:objects];

    // an out of bounds index should return nil
    STAssertNil([transformation transform:self.startValue], @"");

    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSArray array]], @"");
    STAssertNil([transformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testPassthroughTransformation {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
    STAssertEqualObjects([transformation transform:[NSArray array]], [NSArray array], @"");
    STAssertEqualObjects([transformation transform:[NSOrderedSet orderedSet]], [NSOrderedSet orderedSet], @"");
}

- (void)testReverseTransformation {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    PRORemovalTransformation *reverseTransformation = (id)[transformation reverseTransformation];
    STAssertNotNil(reverseTransformation, @"");

    // the reverse of an insertion is a removal
    STAssertTrue([reverseTransformation isKindOfClass:[PRORemovalTransformation class]], @"");

    // indexes and objects should be the same
    STAssertEqualObjects(transformation.insertionIndexes, reverseTransformation.removalIndexes, @"");
    STAssertEqualObjects(transformation.objects, reverseTransformation.expectedObjects, @"");

    // for the reverse transformation, giving the endValue should yield the
    // startValue
    STAssertEqualObjects([reverseTransformation transform:self.endValue], self.startValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.startValue], @"");
    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
    STAssertNil([reverseTransformation transform:[NSArray array]], @"");
    STAssertNil([reverseTransformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testEquality {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    PROInsertionTransformation *equalTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROInsertionTransformation *inequalTransformation = [[PROInsertionTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROInsertionTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROInsertionTransformation *transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];
    PROInsertionTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

- (void)testRewritingTransformations {
    PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:self.indexes objects:self.objects];

    // just pass through values
    PROTransformationRewriterBlock rewriterBlock = ^(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        STAssertEqualObjects([insertionTransformation transform:obj],  transformationBlock(obj), @"");
        STAssertEqualObjects(transformation, insertionTransformation, @"");

        return obj;
    };

    PROTransformationBlock rewrittenBlock = [insertionTransformation transformationBlockUsingRewriterBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    // everything should be passed through
    STAssertEqualObjects(rewrittenBlock(self.startValue), self.startValue, @"");
    STAssertEqualObjects(rewrittenBlock(self.endValue), self.endValue, @"");
    STAssertEqualObjects(rewrittenBlock([NSArray array]), [NSArray array], @"");
    STAssertEqualObjects(rewrittenBlock([NSNull null]), [NSNull null], @"");
}

@end
