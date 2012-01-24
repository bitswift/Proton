//
//  PROHigherOrderAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

SpecBegin(PROHigherOrderAdditions)
    describe(@"dictionary", ^{
    });

    id filterBlock = ^(NSString *str){
        return [str isEqualToString:@"bar"] || [str hasSuffix:@"zz"];
    };

    describe(@"non-empty collection", ^{
        NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", @"buzz", nil];
        NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", @"bizz", nil];
        NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", @"bozz", nil];

        describe(@"filtering", ^{
            NSArray *filteredArray = [NSArray arrayWithObjects:@"bar", @"buzz", nil];
            NSOrderedSet *filteredOrderedSet = [NSOrderedSet orderedSetWithObjects:@"bar", @"bizz", nil];
            NSSet *filteredSet = [NSSet setWithObjects:@"bar", @"bozz", nil];

            it(@"should filter", ^{
                expect([array filterUsingBlock:filterBlock]).toEqual(filteredArray);
                expect([orderedSet filterUsingBlock:filterBlock]).toEqual(filteredOrderedSet);
                expect([set filterUsingBlock:filterBlock]).toEqual(filteredSet);
            });

            it(@"should filter concurrently", ^{
                expect([array filterWithOptions:NSEnumerationConcurrent usingBlock:filterBlock]).toEqual(filteredArray);
                expect([orderedSet filterWithOptions:NSEnumerationConcurrent usingBlock:filterBlock]).toEqual(filteredOrderedSet);
                expect([set filterWithOptions:NSEnumerationConcurrent usingBlock:filterBlock]).toEqual(filteredSet);
            });

            it(@"should filter in reverse", ^{
                expect([array filterWithOptions:NSEnumerationReverse usingBlock:filterBlock]).toEqual([[filteredArray reverseObjectEnumerator] allObjects]);
                expect([[orderedSet filterWithOptions:NSEnumerationReverse usingBlock:filterBlock] array]).toEqual([[filteredOrderedSet reverseObjectEnumerator] allObjects]);
                expect([set filterWithOptions:NSEnumerationReverse usingBlock:filterBlock]).toEqual(filteredSet);
            });

            it(@"should filter to empty collection when not successful", ^{
                id unsuccessfulFilterBlock = ^(NSString *str){
                    return [str isEqualToString:@"not a real string"];
                };

                expect([array filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSArray array]);
                expect([orderedSet filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSOrderedSet orderedSet]);
                expect([set filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSSet set]);
            });
        });
    });

    describe(@"empty collection", ^{
        it(@"should filter to empty collection", ^{
            expect([[NSArray array] filterUsingBlock:filterBlock]).toEqual([NSArray array]);
            expect([[NSOrderedSet orderedSet] filterUsingBlock:filterBlock]).toEqual([NSOrderedSet orderedSet]);
            expect([[NSSet set] filterUsingBlock:filterBlock]).toEqual([NSSet set]);
        });
    });

SpecEnd
