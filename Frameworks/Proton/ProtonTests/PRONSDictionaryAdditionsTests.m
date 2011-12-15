//
//  PRONSDictionaryAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 15.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSDictionaryAdditionsTests.h"
#import <Proton/NSDictionary+HigherOrderAdditions.h>

@interface PRONSDictionaryAdditionsTests ()
- (void)testFilteringWithOptions:(NSEnumerationOptions)opts;
@end

@implementation PRONSDictionaryAdditionsTests

- (void)testFilter {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    NSDictionary *filteredDict = [dict filterEntriesUsingBlock:^(id key, id value) {
        return [key isEqual:@"null"];
    }];

    STAssertEqualObjects(filteredDict, [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"null"], @"");
}

- (void)testFilteringEmptyDictionary {
    NSDictionary *dict = [NSDictionary dictionary];

    NSDictionary *filteredDict = [dict filterEntriesUsingBlock:^(id key, id value) {
        return [key isEqual:@"bar"];
    }];

    STAssertEqualObjects(filteredDict, [NSDictionary dictionary], @"");
}

- (void)testFilteringWithoutSuccess {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    NSDictionary *filteredDict = [dict filterEntriesUsingBlock:^(id key, id value) {
        return [key isEqual:@"quux"];
    }];

    STAssertEqualObjects(filteredDict, [NSDictionary dictionary], @"");
}

- (void)testFilteringConcurrently {
    [self testFilteringWithOptions:NSEnumerationConcurrent];
}

- (void)testFilteringReverse {
    [self testFilteringWithOptions:NSEnumerationReverse];
}

- (void)testFilteringWithOptions:(NSEnumerationOptions)opts {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    NSDictionary *filteredDict = [dict filterEntriesWithOptions:opts usingBlock:^ BOOL (id key, id value) {
        return [key isEqual:@"foo"] || [value isEqual:@"buzz"];
    }];

    NSDictionary *expectedDict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        nil
    ];

    STAssertEqualObjects(filteredDict, expectedDict, @"");
}

@end
