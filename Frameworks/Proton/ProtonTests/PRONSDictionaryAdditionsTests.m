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
- (void)testKeyOfEntryPassingTestWithOptions:(NSEnumerationOptions)opts;
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

- (void)testKeyOfEntryPassingTest {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    id key = [dictionary keyOfEntryPassingTest:^(id key, id obj, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertEqualObjects(key, @"foo", @"");
}

- (void)testKeyOfEntryPassingTestOnEmptyDictionary {
    NSDictionary *dictionary = [NSDictionary dictionary];

    id key = [dictionary keyOfEntryPassingTest:^(id key, id obj, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertNil(key, @"");
}

- (void)testKeyOfEntryPassingTestWithoutSuccess {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    id key = [dictionary keyOfEntryPassingTest:^(id key, id obj, BOOL *stop){
        return [obj isEqual:@"quux"];
    }];

    STAssertNil(key, @"");
}

- (void)testKeyOfEntryPassingTestWithOptions:(NSEnumerationOptions)opts; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"buzz", @"baz",
        [NSNull null], @"null",
        nil
    ];

    id key = [dictionary keyOfEntryWithOptions:opts passingTest:^(id key, id obj, BOOL *stop){
        return [obj isEqual:@"bar"];
    }];

    STAssertEqualObjects(key, @"foo", @"");
}

- (void)testKeyOfEntryPassingTestConcurrently {
    [self testKeyOfEntryPassingTestWithOptions:NSEnumerationConcurrent];
}

- (void)testKeyOfEntryPassingTestReverse {
    [self testKeyOfEntryPassingTestWithOptions:NSEnumerationReverse];
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

- (void)testFold {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"bar", @"buzz",
        [NSNumber numberWithBool:NO], [NSNumber numberWithInt:20],
        @"buzz", @"baz",
        @"foo", @"bar",
        [NSNull null], @"null",
        nil
    ];

    // creates a set of dictionary's string keys and string values
    NSSet *valuesSet = [dict foldEntriesWithValue:[NSSet set] usingBlock:^(NSSet *set, NSString *key, NSString *value){
        STAssertNotNil(set, @"");
        STAssertNotNil(key, @"");
        STAssertNotNil(value, @"");

        if ([key isKindOfClass:[NSString class]])
            set = [set setByAddingObject:key];
        
        if ([value isKindOfClass:[NSString class]])
            set = [set setByAddingObject:value];

        return set;
    }];

    NSSet *expectedSet = [NSSet setWithObjects:@"foo", @"bar", @"buzz", @"baz", @"null", nil];
    STAssertEqualObjects(valuesSet, expectedSet, @"");
}

- (void)testFoldOnEmptyDictionary {
    NSDictionary *dictionary = [NSDictionary dictionary];

    NSString *str = [dictionary foldEntriesWithValue:@"" usingBlock:^ id (id left, id rightKey, id rightValue){
        STFail(@"Folding block should never be invoked if the dictionary is empty");
        return nil;
    }];

    STAssertEqualObjects(str, @"", @"");
}

- (void)testFoldWithNil {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        @"bar", @"foo",
        @"bar", @"buzz",
        [NSNumber numberWithBool:NO], [NSNumber numberWithInt:20],
        @"buzz", @"baz",
        @"foo", @"bar",
        [NSNull null], @"null",
        nil
    ];

    id obj = [dict foldEntriesWithValue:nil usingBlock:^ id (id obj, id key, id value){
        // this will be our starting value, or the last value returned by this
        // block
        STAssertNil(obj, @"");

        // these should be elements of the dictionary
        STAssertNotNil(key, @"");
        STAssertNotNil(value, @"");

        return nil;
    }];

    STAssertNil(obj, @"");
}

@end
