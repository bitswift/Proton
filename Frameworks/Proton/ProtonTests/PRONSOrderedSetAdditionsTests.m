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
@end
