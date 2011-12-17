//
//  PRONSDictionaryAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSDictionaryAdditionsTests.h"
#import <Proton/NSDictionary+HigherOrderAdditions.h>
#import <Proton/NSDictionary+PROKeyedObjectAdditions.h>

@interface PRONSDictionaryAdditionsTests ()
- (void)testFilteringWithOptions:(NSEnumerationOptions)opts;
- (void)testMappingWithOptions:(NSEnumerationOptions)opts;
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

- (void)testMapping {
    [self testMappingWithOptions:0];
}

- (void)testMappingEmptyDictionary {
    NSDictionary *dict = [NSDictionary dictionary];

    NSDictionary *mappedDictionary = [dict mapValuesUsingBlock:^(id key, id value){
        return [value stringByAppendingString:@"buzz"];
    }];

    STAssertEqualObjects(mappedDictionary, [NSDictionary dictionary], @"");
}

- (void)testMappingRemovingElements {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    NSDictionary *mappedDictionary = [dict mapValuesUsingBlock:^(id key, id value){
        if (![key hasPrefix:@"n"])
            return [@"buzz" stringByAppendingString:value];
        else
            return nil;
    }];

    NSDictionary *expectedDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"buzzbar", @"foo",
        @"buzzbuzz", @"baz",
        nil
    ];

    STAssertEqualObjects(mappedDictionary, expectedDictionary, @"");
}

- (void)testMappingConcurrently {
    [self testMappingWithOptions:NSEnumerationConcurrent];
}

- (void)testMappingReverse {
    [self testMappingWithOptions:NSEnumerationReverse];
}

- (void)testMappingWithOptions:(NSEnumerationOptions)opts; {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    NSDictionary *mappedDictionary = [dict mapValuesUsingBlock:^(id key, id value){
        if (![key hasPrefix:@"n"])
            return [@"buzz" stringByAppendingString:value];
        else
            return value;
    }];

    NSDictionary *expectedDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"buzzbar", @"foo",
        @"buzzbuzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    STAssertEqualObjects(mappedDictionary, expectedDictionary, @"");
}

- (void)testPROKeyedObjectAdditions {
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"bar", @"foo",
        [NSNumber numberWithInt:2], [NSNumber numberWithInt:4],
        [NSNull null], @"null",
        nil
    ];

    STAssertEqualObjects([dict dictionaryValue], dict, @"");
}

@end
