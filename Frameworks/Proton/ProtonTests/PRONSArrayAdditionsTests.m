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

@end
