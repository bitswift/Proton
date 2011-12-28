//
//  PRORemovalTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 27.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRORemovalTransformationTests.h"
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
    STAssertEqualObjects(transformation.expectedObjects, [NSArray arrayWithObject:[NSNumber numberWithInt:5]]);
}

- (void)testTransformationInBounds {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([transformation transform:self.startValue], self.endValue, @"");

    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSArray array]], @"");
    STAssertNil([transformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testTransformationOutOfBounds {
    NSIndexSet *outOfBoundsSet = [NSIndexSet indexSetWithIndex:50000];
    NSArray *objects = [NSArray arrayWithObject:[self.objects objectAtIndex:0]];

    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:outOfBoundsSet expectedObjects:objects];

    // an out of bounds index should return nil
    STAssertNil([transformation transform:self.startValue], @"");

    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSArray array]], @"");
    STAssertNil([transformation transform:[NSOrderedSet orderedSet]], @"");
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
    STAssertNil([transformation transform:self.startValue], @"");

    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSArray array]], @"");
    STAssertNil([transformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testPassthroughTransformation {
    PRORemovalTransformation *transformation = [[PRORemovalTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
    STAssertEqualObjects([transformation transform:[NSArray array]], [NSArray array], @"");
    STAssertEqualObjects([transformation transform:[NSOrderedSet orderedSet]], [NSOrderedSet orderedSet], @"");
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
    STAssertEqualObjects([reverseTransformation transform:self.endValue], self.startValue, @"");

    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
    STAssertNil([reverseTransformation transform:[NSArray array]], @"");
    STAssertNil([reverseTransformation transform:[NSOrderedSet orderedSet]], @"");
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

- (void)testRewritingTransformations {
    PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:self.indexes expectedObjects:self.objects];

    // just pass through values
    PROTransformationRewriterBlock rewriterBlock = ^(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        STAssertEqualObjects([removalTransformation transform:obj],  transformationBlock(obj), @"");
        STAssertEqualObjects(transformation, removalTransformation, @"");

        return obj;
    };

    PROTransformationBlock rewrittenBlock = [removalTransformation transformationBlockUsingRewriterBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    // everything should be passed through
    STAssertEqualObjects(rewrittenBlock(self.startValue), self.startValue, @"");
    STAssertEqualObjects(rewrittenBlock(self.endValue), self.endValue, @"");
    STAssertEqualObjects(rewrittenBlock([NSArray array]), [NSArray array], @"");
    STAssertEqualObjects(rewrittenBlock([NSNull null]), [NSNull null], @"");
}

@end
