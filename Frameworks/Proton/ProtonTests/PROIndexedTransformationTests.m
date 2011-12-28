//
//  PROIndexedTransformationTests.m
//  Proton
//
//  Created by Josh Vera on 12/21/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
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
   STAssertEqualObjects(indexedTransformation.transformations, [NSArray arrayWithObject:[self.transformations objectAtIndex:0]]);
}

- (void)testTransformationInBounds {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([indexedTransformation transform:self.startValue], self.endValue, @"");

    STAssertNil([indexedTransformation transform:self.endValue], @"");
    STAssertNil([indexedTransformation transform:[NSNull null]], @"");
    STAssertNil([indexedTransformation transform:[NSArray array]], @"");
    STAssertNil([indexedTransformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testTransformationOutOfBounds {
    NSIndexSet *outOfBoundsSet = [NSIndexSet indexSetWithIndex:50000];
    NSArray *transformations = [NSArray arrayWithObject:[self.transformations objectAtIndex:0]];

    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:outOfBoundsSet transformations:transformations];

    // an out of bounds index should return nil
    STAssertNil([indexedTransformation transform:self.startValue], @"");

    STAssertNil([indexedTransformation transform:self.endValue], @"");
    STAssertNil([indexedTransformation transform:[NSNull null]], @"");
    STAssertNil([indexedTransformation transform:[NSArray array]], @"");
    STAssertNil([indexedTransformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testPassthroughTransformation {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
    STAssertEqualObjects([transformation transform:[NSArray array]], [NSArray array], @"");
    STAssertEqualObjects([transformation transform:[NSOrderedSet orderedSet]], [NSOrderedSet orderedSet], @"");
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
    STAssertEqualObjects([reverseTransformation transform:self.endValue], self.startValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.startValue], @"");
    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
    STAssertNil([reverseTransformation transform:[NSArray array]], @"");
    STAssertNil([reverseTransformation transform:[NSOrderedSet orderedSet]], @"");
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

- (void)testRewritingTransformations {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithIndexes:self.indexes transformations:self.transformations];

    PROTransformationRewriterBlock rewriterBlock = ^(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        if (transformation == indexedTransformation) {
            return transformationBlock(obj);
        }

        STAssertTrue([self.transformations containsObject:transformation], @"");

        // use the reverse of the transformation given
        return [transformation.reverseTransformation transform:obj];
    };

    PROTransformationBlock rewrittenBlock = [indexedTransformation transformationBlockUsingRewriterBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    STAssertEqualObjects(rewrittenBlock(self.endValue), self.startValue, @"");
    STAssertNil(rewrittenBlock(self.startValue), @"");
}

@end
