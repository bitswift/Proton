//
//  PROModelTests.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

//  Logic unit tests contain unit test code that is designed to be linked into an independent test executable.

#import <SenTestingKit/SenTestingKit.h>
#import <Proton/PROModel.h>

@interface PROModelTests : SenTestCase
/*
 * Executes the given block and verifies that the transformed object is correct.
 *
 * @param originalObject The original object (the one to transform).
 * @param transformedObject The expected value for the transformed (resultant)
 * object. This argument may be `nil` to verify that an invalid transformation
 * fails.
 * @param transformationBlock A block containing transformation code to execute.
 */
- (void)verifyObject:(PROModel *)originalObject becomesObject:(PROModel *)transformedObject afterTransformation:(void (^)(void))transformationBlock;
@end
