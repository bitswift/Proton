//
//  PROUniqueTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROUniqueTransformationTests.h"
#import <Proton/Proton.h>

@interface PROUniqueTransformationTests ()
@property (nonatomic, copy, readonly) NSString *inputValue;
@property (nonatomic, copy, readonly) NSString *outputValue;
@end

@implementation PROUniqueTransformationTests

- (NSString *)inputValue {
    return @"inputValue";
}

- (NSString *)outputValue {
    return @"outputValue";
}

- (void)testInitialization {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] init];
    STAssertNotNil(transformation, @"");

    // both values should be nil if not initialized with anything
    STAssertNil(transformation.inputValue, @"");
    STAssertNil(transformation.outputValue, @"");
}

- (void)testInitializationWithValues {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.inputValue, self.inputValue, @"");
    STAssertEqualObjects(transformation.outputValue, self.outputValue, @"");
}

- (void)testInitializationCopyingValues {
    NSMutableString *mutableInputValue = [[NSMutableString alloc] initWithString:self.inputValue];
    NSMutableString *mutableOutputValue = [[NSMutableString alloc] initWithString:self.outputValue];

    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:mutableInputValue outputValue:mutableOutputValue];
    STAssertNotNil(transformation, @"");

    STAssertEqualObjects(transformation.inputValue, mutableInputValue, @"");
    STAssertEqualObjects(transformation.outputValue, mutableOutputValue, @"");
    
    [mutableInputValue appendString:@"foo"];
    [mutableOutputValue appendString:@"bar"];

    // the strings on 'transformation' should be untouched, even though we
    // modified the original
    
    STAssertFalse([mutableInputValue isEqualToString:transformation.inputValue], @"");
    STAssertFalse([mutableOutputValue isEqualToString:transformation.outputValue], @"");
}

- (void)testInitializationEXTNilConversion {
    // providing nil for just the input value or just the output value should
    // silently convert that one value to EXTNil

    {
        PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:nil];
        STAssertNotNil(transformation, @"");

        STAssertEqualObjects(transformation.inputValue, self.inputValue, @"");
        STAssertEqualObjects(transformation.outputValue, [EXTNil null], @"");
    }

    {
        PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:nil outputValue:self.outputValue];
        STAssertNotNil(transformation, @"");

        STAssertEqualObjects(transformation.inputValue, [EXTNil null], @"");
        STAssertEqualObjects(transformation.outputValue, self.outputValue, @"");
    }
}

- (void)testSpecificTransformation {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];

    // giving the inputValue should yield the outputValue
    STAssertEqualObjects([transformation transform:self.inputValue], self.outputValue, @"");

    // anything else should return nil
    STAssertNil([transformation transform:self.outputValue], @"");
    STAssertNil([transformation transform:[NSNull null]], @"");
    STAssertNil([transformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testPassthroughTransformation {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] init];

    // giving any value should yield the same value
    STAssertEqualObjects([transformation transform:self.inputValue], self.inputValue, @"");
    STAssertEqualObjects([transformation transform:self.outputValue], self.outputValue, @"");
    STAssertEqualObjects([transformation transform:[NSNull null]], [NSNull null], @"");
    STAssertEqualObjects([transformation transform:[NSNumber numberWithInt:5]], [NSNumber numberWithInt:5], @"");
}

- (void)testEquality {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];

    PROUniqueTransformation *equalTransformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];
    STAssertEqualObjects(transformation, equalTransformation, @"");

    PROUniqueTransformation *inequalTransformation = [[PROUniqueTransformation alloc] init];
    STAssertFalse([transformation isEqual:inequalTransformation], @"");
}

- (void)testCoding {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];

    NSData *encodedTransformation = [NSKeyedArchiver archivedDataWithRootObject:transformation];
    PROUniqueTransformation *decodedTransformation = [NSKeyedUnarchiver unarchiveObjectWithData:encodedTransformation];

    STAssertEqualObjects(transformation, decodedTransformation, @"");
}

- (void)testCopying {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];
    PROUniqueTransformation *transformationCopy = [transformation copy];

    STAssertEqualObjects(transformation, transformationCopy, @"");
}

- (void)testReverseTransformation {
    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];
    PROTransformation *reverseTransformation = transformation.reverseTransformation;
    
    // for the reverse transformation, giving the outputValue should yield the
    // inputValue
    STAssertEqualObjects([reverseTransformation transform:self.outputValue], self.inputValue, @"");

    // anything else should return nil
    STAssertNil([reverseTransformation transform:self.inputValue], @"");
    STAssertNil([reverseTransformation transform:[NSNull null]], @"");
    STAssertNil([reverseTransformation transform:[NSNumber numberWithInt:5]], @"");
}

- (void)testRewritingTransformations {
    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:self.inputValue outputValue:self.outputValue];
    PROTransformationRewriterBlock rewriterBlock = ^(PROTransformation *transformation, PROTransformationBlock transformationBlock, id obj) {
        STAssertEqualObjects([uniqueTransformation transform:obj],  transformationBlock(obj), @"");
        STAssertEqualObjects(transformation, uniqueTransformation, @"");

        return obj;
    };

    PROTransformationBlock rewrittenBlock = [uniqueTransformation rewrittenTransformationUsingBlock:rewriterBlock];
    STAssertNotNil(rewrittenBlock, @"");
    STAssertEqualObjects(rewrittenBlock(self.inputValue), self.inputValue, @"");
    STAssertEqualObjects(rewrittenBlock(self.outputValue), self.outputValue, @"");
}

@end
