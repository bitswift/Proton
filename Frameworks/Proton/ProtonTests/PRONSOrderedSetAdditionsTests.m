//
//  PRONSOrderedSetAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSOrderedSetAdditionsTests.h"
#import <Proton/NSOrderedSet+HigherOrderAdditions.h>

@interface PRONSOrderedSetAdditionsTests ()
- (void)testFilteringWithOptions:(NSEnumerationOptions)opts;
- (void)testPartitioningWithOptions:(NSEnumerationOptions)opts;
- (void)testMappingWithOptions:(NSEnumerationOptions)opts;
@end

@implementation PRONSOrderedSetAdditionsTests

- (void)testFilter {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *filteredOrderedSet = [orderedSet filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredOrderedSet, [NSOrderedSet orderedSetWithObject:@"bar"], @"");
}

- (void)testFilteringEmptyOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSet];

    NSOrderedSet *filteredOrderedSet = [orderedSet filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredOrderedSet, [NSOrderedSet orderedSet], @"");
}

- (void)testFilteringWithoutSuccess {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *filteredOrderedSet = [orderedSet filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"quux"];
    }];

    STAssertEqualObjects(filteredOrderedSet, [NSOrderedSet orderedSet], @"");
}

- (void)testFilteringConcurrently {
    [self testFilteringWithOptions:NSEnumerationConcurrent];
}

- (void)testFilteringReverse {
    [self testFilteringWithOptions:NSEnumerationReverse];
}

- (void)testFilteringWithOptions:(NSEnumerationOptions)opts {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *filteredOrderedSet = [orderedSet filterWithOptions:opts usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSOrderedSet *testOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", nil];
    STAssertEqualObjects(filteredOrderedSet, testOrderedSet, @"");
}

- (void)testPartitioning; {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *failureOrderedSet = nil;
    NSOrderedSet *successOrderedSet = [orderedSet filterWithFailedObjects:&failureOrderedSet usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSOrderedSet *expectedSuccessOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", nil];
    NSOrderedSet *expectedFailureOrderedSet = [NSOrderedSet orderedSetWithObjects:@"baz", nil];

    STAssertEqualObjects(successOrderedSet, expectedSuccessOrderedSet, @"");
    STAssertEqualObjects(failureOrderedSet, expectedFailureOrderedSet, @"");
}

- (void)testPartitioningEmptyOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSet];

    NSOrderedSet *failureOrderedSet = nil;
    NSOrderedSet *successOrderedSet = [orderedSet filterWithFailedObjects:&failureOrderedSet usingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    NSOrderedSet *expectedSuccessOrderedSet = [NSOrderedSet orderedSet];
    NSOrderedSet *expectedFailureOrderedSet = [NSOrderedSet orderedSet];

    STAssertEqualObjects(successOrderedSet, expectedSuccessOrderedSet, @"");
    STAssertEqualObjects(failureOrderedSet, expectedFailureOrderedSet, @"");
}

- (void)testPartitioningWithoutSuccess {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *failureOrderedSet = nil;
    NSOrderedSet *successOrderedSet = [orderedSet filterWithFailedObjects:&failureOrderedSet usingBlock:^(NSString *string) {
        return [string isEqualToString:@"quux"];
    }];

    NSOrderedSet *expectedSuccessOrderedSet = [NSOrderedSet orderedSet];
    NSOrderedSet *expectedFailureOrderedSet = orderedSet;

    STAssertEqualObjects(successOrderedSet, expectedSuccessOrderedSet, @"");
    STAssertEqualObjects(failureOrderedSet, expectedFailureOrderedSet, @"");
}

- (void)testPartitioningWithNullFailedOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *successOrderedSet = [orderedSet filterWithFailedObjects:NULL usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSOrderedSet *expectedSuccessOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", nil];
    STAssertEqualObjects(successOrderedSet, expectedSuccessOrderedSet, @"");
}

- (void)testPartitioningConcurrently {
    [self testPartitioningWithOptions:NSEnumerationConcurrent];
}

- (void)testPartitioningReverse {
    [self testPartitioningWithOptions:NSEnumerationReverse];
}

- (void)testPartitioningWithOptions:(NSEnumerationOptions)opts; {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *failureOrderedSet = nil;
    NSOrderedSet *successOrderedSet = [orderedSet filterWithOptions:opts failedObjects:&failureOrderedSet usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSOrderedSet *expectedSuccessOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", nil];
    NSOrderedSet *expectedFailureOrderedSet = [NSOrderedSet orderedSetWithObjects:@"baz", nil];

    STAssertEqualObjects(successOrderedSet, expectedSuccessOrderedSet, @"");
    STAssertEqualObjects(failureOrderedSet, expectedFailureOrderedSet, @"");
}

- (void)testMapping {
    [self testMappingWithOptions:0];
}

- (void)testMappingEmptyOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSet];

    NSOrderedSet *mappedOrderedSet = [orderedSet mapUsingBlock:^(NSString *obj){
        return [obj stringByAppendingString:@"buzz"];
    }];

    STAssertEqualObjects(mappedOrderedSet, [NSOrderedSet orderedSet], @"");
}

- (void)testMappingRemovingElements {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSOrderedSet *mappedOrderedSet = [orderedSet mapUsingBlock:^(NSString *obj){
        if ([obj hasPrefix:@"b"])
            return [@"buzz" stringByAppendingString:obj];
        else
            return nil;
    }];

    NSOrderedSet *expectedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"buzzbar", @"buzzbaz", nil];
    STAssertEqualObjects(mappedOrderedSet, expectedOrderedSet, @"");
}

- (void)testMappingConcurrently {
    [self testMappingWithOptions:NSEnumerationConcurrent];
}

- (void)testMappingReverse {
    [self testMappingWithOptions:NSEnumerationReverse];
}

- (void)testMappingWithOptions:(NSEnumerationOptions)opts; {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", @"barbuzz", nil];

    NSOrderedSet *mappedOrderedSet = [orderedSet mapWithOptions:opts usingBlock:^(NSString *obj){
        // 'barbuzz' should be created twice -- since it's a set, only the first
        // one should remain in the result
        if ([obj rangeOfString:@"buzz"].location == NSNotFound)
            return [obj stringByAppendingString:@"buzz"];
        else
            return obj;
    }];

    NSOrderedSet *expectedOrderedSet;

    if (opts & NSEnumerationReverse) {
        // the order of this one is not exactly the reverse of the normal case,
        // since there are two 'barbuzz' entries, and the first one is the one
        // whose index is used
        expectedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"barbuzz", @"bazbuzz", @"foobuzz", nil];
    } else {
        expectedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", nil];
    }

    STAssertEqualObjects(mappedOrderedSet, expectedOrderedSet, @"");
}

- (void)testLeftFold {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [orderedSet foldLeftWithValue:@"buzz" usingBlock:^(NSString *left, NSString *right){
        STAssertNotNil(left, @"");
        STAssertNotNil(right, @"");

        return [left stringByAppendingString:right];
    }];

    STAssertEqualObjects(str, @"buzzfoobarbaz", @"");
}

- (void)testLeftFoldOnEmptyOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSet];

    NSString *str = [orderedSet foldLeftWithValue:@"" usingBlock:^ id (id left, id right){
        STFail(@"Folding block should never be invoked if the orderedSet is empty");
        return nil;
    }];

    STAssertEqualObjects(str, @"", @"");
}

- (void)testLeftFoldWithNil {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [orderedSet foldLeftWithValue:nil usingBlock:^ id (NSString *left, NSString *right){
        // 'left' should be our given value or a result previously returned from
        // this block
        STAssertNil(left, @"");

        // 'right' should be a string from the ordered set
        STAssertNotNil(right, @"");

        return nil;
    }];

    STAssertNil(str, @"");
}

- (void)testRightFold {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [orderedSet foldRightWithValue:@"buzz" usingBlock:^(NSString *left, NSString *right){
        STAssertNotNil(left, @"");
        STAssertNotNil(right, @"");

        return [left stringByAppendingString:right];
    }];

    STAssertEqualObjects(str, @"foobarbazbuzz", @"");
}

- (void)testRightFoldOnEmptyOrderedSet {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSet];

    NSString *str = [orderedSet foldRightWithValue:@"" usingBlock:^ id (id left, id right){
        STFail(@"Folding block should never be invoked if the ordered set is empty");
        return nil;
    }];

    STAssertEqualObjects(str, @"", @"");
}

- (void)testRightFoldWithNil {
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", nil];

    NSString *str = [orderedSet foldRightWithValue:nil usingBlock:^ id (NSString *left, NSString *right){
        // 'left' should be a string from the ordered set
        STAssertNotNil(left, @"");

        // 'right' should be our given value or a result previously returned from
        // this block
        STAssertNil(right, @"");

        return nil;
    }];

    STAssertNil(str, @"");
}
@end
