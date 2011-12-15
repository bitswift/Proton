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

@end
