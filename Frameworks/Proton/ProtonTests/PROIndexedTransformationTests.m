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
@property (nonatomic, copy, readonly) PROUniqueTransformation *uniqueTransformation;
@property (nonatomic, copy, readonly) NSArray *startValue;
@property (nonatomic, copy, readonly) NSArray *endValue;
@property (nonatomic, assign, readonly) NSUInteger index;
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
        @"foo",
        nil
    ];
}

- (PROUniqueTransformation *)uniqueTransformation {
    id inputValue = [NSNumber numberWithInt:5];
    id outputValue = [NSNumber numberWithBool:NO];
    return [[PROUniqueTransformation alloc] initWithInputValue:inputValue outputValue:outputValue];
}

- (NSUInteger)index {
    return 1;
}

- (void)testInitialization {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] init];
    STAssertNotNil(transformation, @"");
    STAssertNil(transformation.transformation, @"");
    STAssertTrue(transformation.index == 0, @"");
}

- (void)testInitializationWithTransformation {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];
    STAssertNotNil(indexedTransformation, @"");
    STAssertEqualObjects(indexedTransformation.transformation, self.uniqueTransformation, @"");
    STAssertTrue(indexedTransformation.index == self.index, @"");
}

- (void)testTransformationInBounds {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    // giving the startValue should yield the endValue
    STAssertEqualObjects([indexedTransformation transform:self.startValue], self.endValue, @"");

    STAssertNil([indexedTransformation transform:self.endValue], @"");
    STAssertNil([indexedTransformation transform:[NSNull null]], @"");
    STAssertNil([indexedTransformation transform:[NSArray array]], @"");
    STAssertNil([indexedTransformation transform:[NSOrderedSet orderedSet]], @"");
}

- (void)testTransformationOutOfBounds {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:50000];

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
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    PROIndexedTransformation *reverseTransformation = (id)[transformation reverseTransformation];
    STAssertNotNil(reverseTransformation, @"");

    // the reverse transformation of the transformation-at-the-index
    // should be the transformation-at-the-index of our reverse
    // transformation
    STAssertEqualObjects(transformation.transformation.reverseTransformation, reverseTransformation.transformation, @"");

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
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    PROIndexedTransformation *equalTransformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROIndexedTransformation *inequalTransformation = [[PROIndexedTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROIndexedTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROIndexedTransformation *transformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];
    PROIndexedTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

- (void)testRewritingTransformations {
    PROIndexedTransformation *indexedTransformation = [[PROIndexedTransformation alloc] initWithTransformation:self.uniqueTransformation index:self.index];

    id uniqueStartValue = [self.endValue objectAtIndex:indexedTransformation.index];
    id uniqueEndValue = [self.startValue objectAtIndex:indexedTransformation.index];

    PROUniqueTransformation *modifiedUniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:uniqueStartValue outputValue:uniqueEndValue];

    PROTransformationRewriterBlock rewriterBlock = ^(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        if (transformation == indexedTransformation) {
            return transformationBlock(obj);
        }

        STAssertEqualObjects(transformation, self.uniqueTransformation, @"");

        // discard the unique transformation given and use our own
        return [modifiedUniqueTransformation transform:obj];
    };

    PROTransformationBlock rewrittenBlock = [indexedTransformation rewrittenTransformationUsingBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    STAssertEqualObjects(rewrittenBlock(self.endValue), self.startValue, @"");
    STAssertNil(rewrittenBlock(self.startValue), @"");
}

@end
