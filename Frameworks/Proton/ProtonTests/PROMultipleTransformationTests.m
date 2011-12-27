//
//  PROMultipleTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROMultipleTransformationTests.h"
#import <Proton/Proton.h>

@interface PROMultipleTransformationTests ()
@property (nonatomic, copy, readonly) NSString *startValue;
@property (nonatomic, copy, readonly) NSString *middleValue;
@property (nonatomic, copy, readonly) NSString *endValue;
@property (nonatomic, copy, readonly) NSArray *transformations;
@end

@implementation PROMultipleTransformationTests

- (NSString *)startValue {
    return @"startValue";
}

- (NSString *)middleValue {
    return @"middleValue";
}

- (NSString *)endValue {
    return @"endValue";
}

- (NSArray *)transformations {
    NSMutableArray *transformations = [[NSMutableArray alloc] init];

    // start -> middle
    [transformations addObject:[[PROUniqueTransformation alloc] initWithInputValue:self.startValue outputValue:self.middleValue]];

    // middle -> end
    [transformations addObject:[[PROUniqueTransformation alloc] initWithInputValue:self.middleValue outputValue:self.endValue]];

    // a PROMultipleTransformation initialized with this array should now be:
    // start -> middle -> end
    return transformations;
}

- (void)testInitialization {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] init];
    STAssertNotNil(transformation, @"");
    
    // a multiple transformation without child transformations should have an
    // empty 'transformations' array (it should not be 'nil', since the class
    // supports children)
    STAssertEqualObjects(transformation.transformations, [NSArray array], @"");
}

- (void)testInitializationWithTransformations {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.transformations, self.transformations, @"");
}

- (void)testMultipleTransformations {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];

    // giving the startValue should yield the endValue (converting through the
    // middleValue)
    STAssertEqualObjects([transformation transform:self.startValue], self.endValue, @"");

    // anything else should return nil
    STAssertNil([transformation transform:self.middleValue], @"");
    STAssertNil([transformation transform:self.endValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testPassthroughTransformation {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.startValue], self.startValue, @"");
    STAssertEqualObjects([transformation transform:self.middleValue], self.middleValue, @"");
    STAssertEqualObjects([transformation transform:self.endValue], self.endValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
}

- (void)testEquality {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];

    PROMultipleTransformation *equalTransformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROMultipleTransformation *inequalTransformation = [[PROMultipleTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROMultipleTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];
    PROMultipleTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

- (void)testReverseTransformation {
    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations];

    PROMultipleTransformation *reverseTransformation = (id)transformation.reverseTransformation;

    // the transformations of the reverse transformation should be the original
    // transformations, each individually reversed, and then overall reversed in
    // order as well
    
    NSMutableArray *reverseTransformations = [[NSMutableArray alloc] init];
    [self.transformations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PROTransformation *t, NSUInteger index, BOOL *stop){
        [reverseTransformations addObject:t.reverseTransformation];
    }];

    STAssertEqualObjects(reverseTransformation.transformations, reverseTransformations, @"");
    
    // for the reverse transformation, giving the endValue should yield the
    // startValue
    STAssertEqualObjects([reverseTransformation transform:self.endValue], self.startValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.startValue], @"");
    STAssertNil([reverseTransformation transform:self.middleValue], @"");
    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testRewritingTransformations {
    PROMultipleTransformation *multipleTransformation = [[PROMultipleTransformation alloc] initWithTransformations:self.transformations]; 

    PROTransformationRewriterBlock rewriterBlock = ^ id (PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        id result = transformationBlock(obj);

        // anything invalid for this transformation will be invalid for our
        // rewritten one as well
        if (!result)
            return nil;

        // otherwise, if the input was the middle value, don't return anything
        // farther than that
        if ([obj isEqual:self.middleValue])
            return obj;

        return result;
    };

    PROTransformationBlock rewrittenBlock = [multipleTransformation transformationBlockUsingRewriterBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");

    STAssertEqualObjects(rewrittenBlock(self.startValue), self.middleValue, @"");
    
    // Input isn't valid for the first transformation
    STAssertNil(rewrittenBlock(self.middleValue), @"");
    STAssertNil(rewrittenBlock(self.endValue), @"");
}

@end
