//
//  PRONSSetAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSSetAdditionsTests.h"
#import <Proton/NSSet+HigherOrderAdditions.h>

@interface PRONSSetAdditionsTests ()
- (void)testFilteringWithOptions:(NSEnumerationOptions)opts;
- (void)testMappingWithOptions:(NSEnumerationOptions)opts;
@end

@implementation PRONSSetAdditionsTests

- (void)testFilter {
    NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", nil];

    NSSet *filteredSet = [set filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredSet, [NSSet setWithObject:@"bar"], @"");
}

- (void)testFilteringEmptySet {
    NSSet *set = [NSSet set];

    NSSet *filteredSet = [set filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"bar"];
    }];

    STAssertEqualObjects(filteredSet, [NSSet set], @"");
}

- (void)testFilteringWithoutSuccess {
    NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", nil];

    NSSet *filteredSet = [set filterUsingBlock:^(NSString *string) {
        return [string isEqualToString:@"quux"];
    }];

    STAssertEqualObjects(filteredSet, [NSSet set], @"");
}

- (void)testFilteringConcurrently {
    [self testFilteringWithOptions:NSEnumerationConcurrent];
}

- (void)testFilteringReverse {
    [self testFilteringWithOptions:NSEnumerationReverse];
}

- (void)testFilteringWithOptions:(NSEnumerationOptions)opts {
    NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", nil];

    NSSet *filteredSet = [set filterWithOptions:opts usingBlock:^(NSString *string) {
        if ([string isEqualToString:@"bar"] || [string isEqualToString:@"foo"])
            return YES;
        else
            return NO;
    }];

    NSSet *testSet = [NSSet setWithObjects:@"foo", @"bar", nil];
    STAssertEqualObjects(filteredSet, testSet, @"");
}

- (void)testMapping {
    [self testMappingWithOptions:0];
}

- (void)testMappingEmptySet {
    NSSet *set = [NSSet set];

    NSSet *mappedSet = [set mapUsingBlock:^(NSString *obj){
        return [obj stringByAppendingString:@"buzz"];
    }];

    STAssertEqualObjects(mappedSet, [NSSet set], @"");
}

- (void)testMappingRemovingElements {
    NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", nil];

    NSSet *mappedSet = [set mapUsingBlock:^(NSString *obj){
        if ([obj hasPrefix:@"b"])
            return [@"buzz" stringByAppendingString:obj];
        else
            return nil;
    }];

    NSSet *expectedSet = [NSSet setWithObjects:@"buzzbar", @"buzzbaz", nil];
    STAssertEqualObjects(mappedSet, expectedSet, @"");
}

- (void)testMappingConcurrently {
    [self testMappingWithOptions:NSEnumerationConcurrent];
}

- (void)testMappingReverse {
    [self testMappingWithOptions:NSEnumerationReverse];
}

- (void)testMappingWithOptions:(NSEnumerationOptions)opts; {
    NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", @"barbuzz", nil];

    NSSet *mappedSet = [set mapWithOptions:opts usingBlock:^(NSString *obj){
        // 'barbuzz' should be created twice -- since it's a set, only one
        // should remain in the result
        if ([obj rangeOfString:@"buzz"].location == NSNotFound)
            return [obj stringByAppendingString:@"buzz"];
        else
            return obj;
    }];

    NSSet *expectedSet = [NSSet setWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", nil];
    STAssertEqualObjects(mappedSet, expectedSet, @"");
}

@end
