//
//  PRONSArrayAdditionsTests.m
//  Proton
//
//  Created by Josh Vera on 12/7/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSArrayAdditionsTests.h"
#import <Proton/NSArray+HigherOrderAdditions.h>

@interface PRONSArrayAdditionsTests ()
- (void)testFilteringWithOptions:(NSEnumerationOptions)opts;
- (void)testPartitioningWithOptions:(NSEnumerationOptions)opts;
- (void)testMappingWithOptions:(NSEnumerationOptions)opts;
@end

@implementation PRONSArrayAdditionsTests

- (void)testFilter {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *filteredArray = [array filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredArray, [NSArray arrayWithObject:@"bar"], @"");
}

- (void)testFilteringEmptyArray {
    NSArray *array = [NSArray array];

    NSArray *filteredArray = [array filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredArray, [NSArray array], @"");
}

- (void)testFilteringWithoutSuccess {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *filteredArray = [array filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"quux"];
    }];

    STAssertEqualObjects(filteredArray, [NSArray array], @"");
}

- (void)testFilteringConcurrently {
    [self testFilteringWithOptions:NSEnumerationConcurrent];
}

- (void)testFilteringReverse {
    [self testFilteringWithOptions:NSEnumerationReverse];
}

- (void)testFilteringWithOptions:(NSEnumerationOptions)opts {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *filteredArray = [array filterWithOptions:opts usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSArray *testArray = [NSArray arrayWithObjects:@"foo", @"bar", nil];
    STAssertEqualObjects(filteredArray, testArray, @"");
}

- (void)testPartitioning; {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *failureArray = nil;
    NSArray *successArray = [array filterWithFailedObjects:&failureArray usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSArray *expectedSuccessArray = [NSArray arrayWithObjects:@"foo", @"bar", nil];
    NSArray *expectedFailureArray = [NSArray arrayWithObjects:@"baz", nil];

    STAssertEqualObjects(successArray, expectedSuccessArray, @"");
    STAssertEqualObjects(failureArray, expectedFailureArray, @"");
}

- (void)testPartitioningEmptyArray {
    NSArray *array = [NSArray array];

    NSArray *failureArray = nil;
    NSArray *successArray = [array filterWithFailedObjects:&failureArray usingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    NSArray *expectedSuccessArray = [NSArray array];
    NSArray *expectedFailureArray = [NSArray array];

    STAssertEqualObjects(successArray, expectedSuccessArray, @"");
    STAssertEqualObjects(failureArray, expectedFailureArray, @"");
}

- (void)testPartitioningWithoutSuccess {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *failureArray = nil;
    NSArray *successArray = [array filterWithFailedObjects:&failureArray usingBlock:^(NSString *string) {
        return [string isEqualToString:@"quux"];
    }];

    NSArray *expectedSuccessArray = [NSArray array];
    NSArray *expectedFailureArray = array;

    STAssertEqualObjects(successArray, expectedSuccessArray, @"");
    STAssertEqualObjects(failureArray, expectedFailureArray, @"");
}

- (void)testPartitioningWithNullFailedArray {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *successArray = [array filterWithFailedObjects:NULL usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSArray *expectedSuccessArray = [NSArray arrayWithObjects:@"foo", @"bar", nil];
    STAssertEqualObjects(successArray, expectedSuccessArray, @"");
}

- (void)testPartitioningConcurrently {
    [self testPartitioningWithOptions:NSEnumerationConcurrent];
}

- (void)testPartitioningReverse {
    [self testPartitioningWithOptions:NSEnumerationReverse];
}

- (void)testPartitioningWithOptions:(NSEnumerationOptions)opts; {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *failureArray = nil;
    NSArray *successArray = [array filterWithOptions:opts failedObjects:&failureArray usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSArray *expectedSuccessArray = [NSArray arrayWithObjects:@"foo", @"bar", nil];
    NSArray *expectedFailureArray = [NSArray arrayWithObjects:@"baz", nil];

    STAssertEqualObjects(successArray, expectedSuccessArray, @"");
    STAssertEqualObjects(failureArray, expectedFailureArray, @"");
}

- (void)testObjectPassingTest {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    id obj = [array objectPassingTest:^(id obj, NSUInteger index, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertEqualObjects(obj, @"bar", @"");
}

- (void)testObjectPassingTestOnEmptyArray {
    NSArray *array = [NSArray array];

    id obj = [array objectPassingTest:^(id obj, NSUInteger index, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertNil(obj, @"");
}

- (void)testObjectPassingTestWithoutSuccess {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    id obj = [array objectPassingTest:^(id obj, NSUInteger index, BOOL *stop){
        return [obj isEqual:@"quux"];
    }];

    STAssertNil(obj, @"");
}

- (void)testObjectPassingTestWithStop {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    id obj = [array objectPassingTest:^(id obj, NSUInteger index, BOOL *stop){
        *stop = YES;
        return [obj isEqual:@"bar"];
    }];

    STAssertNil(obj, @"");
}

- (void)testObjectPassingTestConcurrently {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    id obj = [array objectWithOptions:NSEnumerationConcurrent passingTest:^(id obj, NSUInteger index, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertEqualObjects(obj, @"bar", @"");
}

- (void)testObjectPassingTestReverse {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", @"quux", nil];

    id obj = [array objectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id obj, NSUInteger index, BOOL *stop){
        return (index % 2 == 0);
    }];

    // this is the last object with an even index
    STAssertEqualObjects(obj, @"baz", @"");
}

- (void)testMapping {
    [self testMappingWithOptions:0];
}

- (void)testMappingEmptyArray {
    NSArray *array = [NSArray array];

    NSArray *mappedArray = [array mapUsingBlock:^(NSString *obj){
        return [obj stringByAppendingString:@"buzz"];
    }];

    STAssertEqualObjects(mappedArray, [NSArray array], @"");
}

- (void)testMappingRemovingElements {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *mappedArray = [array mapUsingBlock:^(NSString *obj){
        if ([obj hasPrefix:@"b"])
            return [@"buzz" stringByAppendingString:obj];
        else
            return nil;
    }];

    NSArray *expectedArray = [NSArray arrayWithObjects:@"buzzbar", @"buzzbaz", nil];
    STAssertEqualObjects(mappedArray, expectedArray, @"");
}

- (void)testMappingConcurrently {
    [self testMappingWithOptions:NSEnumerationConcurrent];
}

- (void)testMappingReverse {
    [self testMappingWithOptions:NSEnumerationReverse];
}

- (void)testMappingWithOptions:(NSEnumerationOptions)opts; {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSArray *mappedArray = [array mapWithOptions:opts usingBlock:^(NSString *obj){
        return [obj stringByAppendingString:@"buzz"];
    }];

    NSArray *expectedArray = [NSArray arrayWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", nil];
    if (opts & NSEnumerationReverse) {
        // reverse the expected array
        expectedArray = [[expectedArray reverseObjectEnumerator] allObjects];
    }

    STAssertEqualObjects(mappedArray, expectedArray, @"");
}

- (void)testLeftFold {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [array foldLeftWithValue:@"buzz" usingBlock:^(NSString *left, NSString *right){
        STAssertNotNil(left, @"");
        STAssertNotNil(right, @"");

        return [left stringByAppendingString:right];
    }];

    STAssertEqualObjects(str, @"buzzfoobarbaz", @"");
}

- (void)testLeftFoldOnEmptyArray {
    NSArray *array = [NSArray array];

    NSString *str = [array foldLeftWithValue:@"" usingBlock:^ id (id left, id right){
        STFail(@"Folding block should never be invoked if the array is empty");
        return nil;
    }];

    STAssertEqualObjects(str, @"", @"");
}

- (void)testLeftFoldWithNil {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [array foldLeftWithValue:nil usingBlock:^ id (NSString *left, NSString *right){
        // 'left' should be our given value or a result previously returned from
        // this block
        STAssertNil(left, @"");

        // 'right' should be a string from the array
        STAssertNotNil(right, @"");

        return nil;
    }];

    STAssertNil(str, @"");
}

- (void)testRightFold {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [array foldRightWithValue:@"buzz" usingBlock:^(NSString *left, NSString *right){
        STAssertNotNil(left, @"");
        STAssertNotNil(right, @"");

        return [left stringByAppendingString:right];
    }];

    STAssertEqualObjects(str, @"foobarbazbuzz", @"");
}

- (void)testRightFoldOnEmptyArray {
    NSArray *array = [NSArray array];

    NSString *str = [array foldRightWithValue:@"" usingBlock:^ id (id left, id right){
        STFail(@"Folding block should never be invoked if the array is empty");
        return nil;
    }];

    STAssertEqualObjects(str, @"", @"");
}

- (void)testRightFoldWithNil {
    NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [array foldRightWithValue:nil usingBlock:^ id (NSString *left, NSString *right){
        // 'left' should be a string from the array
        STAssertNotNil(left, @"");

        // 'right' should be our given value or a result previously returned from
        // this block
        STAssertNil(right, @"");

        return nil;
    }];

    STAssertNil(str, @"");
}

@end
