//
//  PRONSArrayAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 19.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

SpecBegin(PRONSArrayAdditions)
    
    describe(@"longest common subarray", ^{
        // this should be set to nil if the arrays don't have anything in common
        __block NSArray *commonSubarray;

        // created as copies of the common subarray to start with
        __block NSMutableArray *firstArray;
        __block NSMutableArray *secondArray;

        before(^{
            commonSubarray = [NSArray arrayWithObjects:@"foo", @"bar", @"null", nil];

            firstArray = [NSMutableArray arrayWithObjects:[@"foo" mutableCopy], @"bar", @"null", nil];
            secondArray = [NSMutableArray arrayWithObjects:@"foo", [@"bar" mutableCopy], [@"null" mutableCopy], nil];
        });

        after(^{
            expect([firstArray longestSubarrayCommonWithArray:secondArray]).toEqual(commonSubarray);

            __block NSRange firstRange = NSMakeRange(0, 0);
            __block NSRange secondRange = NSMakeRange(0, 0);
            expect([firstArray longestSubarrayCommonWithArray:secondArray rangeInReceiver:&firstRange rangeInOtherArray:&secondRange]).toEqual(commonSubarray);

            if (commonSubarray) {
                expect([firstArray subarrayWithRange:firstRange]).toEqual(commonSubarray);
                expect([secondArray subarrayWithRange:secondRange]).toEqual(commonSubarray);
            } else {
                expect(firstRange.location).toEqual(NSNotFound);
                expect(secondRange.location).toEqual(NSNotFound);
            }
        });

        it(@"should return the full array for a common subarray of the same arrays", ^{
            // just invoke the before() and after() blocks, without making any
            // changes to the arrays
        });

        it(@"should find common subarray at the beginning", ^{
            [firstArray addObject:@"fizz"];
            [secondArray addObject:@"quux"];
        });

        it(@"should find common subarray with one array being the subarray", ^{
            [firstArray addObject:@"fizz"];
        });

        it(@"should find common subarray in the middle", ^{
            [firstArray addObject:@"fizz"];
            [firstArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:0];
        });

        it(@"should find common subarray at the end", ^{
            [firstArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:1];
        });

        it(@"should find the longer of two common subarrays", ^{
            [firstArray insertObject:@"quux" atIndex:0];
            [firstArray insertObject:@"fizz" atIndex:1];
            [firstArray insertObject:[NSNull null] atIndex:2];

            [secondArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:1];
            [secondArray insertObject:[NSNumber numberWithInt:5] atIndex:2];
        });

        it(@"should return nil if nothing is common", ^{
            [secondArray removeAllObjects];
            [secondArray addObject:@"fizz"];

            commonSubarray = nil;
        });
    });
    
    describe(@"longest identical subarray", ^{
        // this should be set to nil if the arrays don't have anything identical
        __block NSArray *identicalSubarray;

        // created as copies of the identical subarray to start with
        __block NSMutableArray *firstArray;
        __block NSMutableArray *secondArray;

        before(^{
            identicalSubarray = [NSArray arrayWithObjects:@"foo", @"bar", @"null", nil];

            firstArray = [identicalSubarray mutableCopy];
            secondArray = [identicalSubarray mutableCopy];
        });

        after(^{
            expect([firstArray longestSubarrayIdenticalWithArray:secondArray]).toEqual(identicalSubarray);

            __block NSRange firstRange = NSMakeRange(0, 0);
            __block NSRange secondRange = NSMakeRange(0, 0);
            expect([firstArray longestSubarrayIdenticalWithArray:secondArray rangeInReceiver:&firstRange rangeInOtherArray:&secondRange]).toEqual(identicalSubarray);

            if (identicalSubarray) {
                expect([firstArray subarrayWithRange:firstRange]).toEqual(identicalSubarray);
                expect([secondArray subarrayWithRange:secondRange]).toEqual(identicalSubarray);
            } else {
                expect(firstRange.location).toEqual(NSNotFound);
                expect(secondRange.location).toEqual(NSNotFound);
            }
        });

        it(@"should return the full array for a identical subarray of the same arrays", ^{
            // just invoke the before() and after() blocks, without making any
            // changes to the arrays
        });

        it(@"should find identical subarray at the beginning", ^{
            [firstArray addObject:@"fizz"];
            [secondArray addObject:@"quux"];
        });

        it(@"should find identical subarray with one array being the subarray", ^{
            [firstArray addObject:@"fizz"];
        });

        it(@"should find identical subarray in the middle", ^{
            [firstArray addObject:@"fizz"];
            [firstArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:0];
        });

        it(@"should find identical subarray at the end", ^{
            [firstArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:1];
        });

        it(@"should find the longer of two identical subarrays", ^{
            [firstArray insertObject:@"quux" atIndex:0];
            [firstArray insertObject:@"fizz" atIndex:1];
            [firstArray insertObject:[NSNull null] atIndex:2];

            [secondArray insertObject:@"quux" atIndex:0];
            [secondArray insertObject:@"fizz" atIndex:1];
            [secondArray insertObject:[NSNumber numberWithInt:5] atIndex:2];
        });

        it(@"should return nil if nothing is identical", ^{
            [secondArray removeAllObjects];
            [secondArray addObject:@"fizz"];

            identicalSubarray = nil;
        });
    });

    describe(@"object at index path", ^{
        __block NSArray *array;

        before(^{
            array = [NSArray arrayWithObjects:
                // [0]
                @"foo",

                // [0].[0, 1]
                [NSArray arrayWithObjects:@"foo", @"bar", nil],

                // [0].bar.[0]
                [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:@"foo"] forKey:@"bar"],

                nil
            ];

            expect(array).not.toBeNil();
        });

        it(@"should return the array for an empty index path", ^{
            NSIndexPath *emptyPath = [NSIndexPath indexPathWithIndexes:NULL length:0];
            expect(emptyPath).not.toBeNil();

            expect([array objectAtIndexPath:emptyPath]).toEqual(array);
            expect([array objectAtIndexPath:emptyPath nodeKeyPath:nil]).toEqual(array);
            expect([array objectAtIndexPath:emptyPath nodeKeyPath:@"bar"]).toEqual(array);
        });

        it(@"should return nil for an index path where an index is not an array", ^{
            NSUInteger indexes[] = { 0, 1 };
            NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];

            expect([array objectAtIndexPath:indexPath]).toBeNil();
            expect([array objectAtIndexPath:indexPath nodeKeyPath:nil]).toBeNil();
        });

        it(@"should return a top-level object", ^{
            NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:0];
            id object = [array objectAtIndex:0];

            expect([array objectAtIndexPath:indexPath]).toEqual(object);
            expect([array objectAtIndexPath:indexPath nodeKeyPath:nil]).toEqual(object);
            expect([array objectAtIndexPath:indexPath nodeKeyPath:@"bar"]).toEqual(object);
        });

        it(@"should return a nested object without a key path", ^{
            NSUInteger indexes[] = { 1, 0 };
            NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
            id object = [[array objectAtIndex:1] objectAtIndex:0];

            expect([array objectAtIndexPath:indexPath]).toEqual(object);
            expect([array objectAtIndexPath:indexPath nodeKeyPath:nil]).toEqual(object);
        });

        it(@"should return a nested object with a key path", ^{
            NSUInteger indexes[] = { 2, 0 };
            NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
            id object = [[[array objectAtIndex:2] valueForKey:@"bar"] objectAtIndex:0];

            expect([array objectAtIndexPath:indexPath nodeKeyPath:@"bar"]).toEqual(object);
        });
    });

SpecEnd
