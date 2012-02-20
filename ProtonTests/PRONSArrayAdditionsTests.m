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
            // all the logic of this test exists above
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
        // this should be set to nil if the arrays don't have anything in identical
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
            // all the logic of this test exists above
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

SpecEnd
