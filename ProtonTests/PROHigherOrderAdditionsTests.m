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
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"bar", @"foo",
            @"bar", @"buzz",
            [NSNumber numberWithBool:NO], [NSNumber numberWithInt:20],
            @"buzz", @"baz",
            @"foo", @"bar",
            [NSNull null], @"null",
            nil
        ];

        describe(@"successful filtering", ^{
            id filterBlock = ^(id key, id value){
                return [key isEqual:@"foo"] || [value isEqual:@"buzz"];
            };

            NSDictionary *filteredDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                @"bar", @"foo",
                @"buzz", @"baz",
                nil
            ];

            it(@"should filter", ^{
                expect([dictionary filterEntriesUsingBlock:filterBlock]).toEqual(filteredDictionary);
            });

            it(@"should filter concurrently", ^{
                expect([dictionary filterEntriesWithOptions:NSEnumerationConcurrent usingBlock:filterBlock]).toEqual(filteredDictionary);
            });

            it(@"should filter in reverse", ^{
                expect([dictionary filterEntriesWithOptions:NSEnumerationReverse usingBlock:filterBlock]).toEqual(filteredDictionary);
            });

            it(@"should filter to empty dictionary", ^{
                expect([[NSDictionary dictionary] filterEntriesUsingBlock:filterBlock]).toEqual([NSDictionary dictionary]);
            });

            NSDictionary *failedDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                @"bar", @"buzz",
                [NSNumber numberWithBool:NO], [NSNumber numberWithInt:20],
                @"foo", @"bar",
                [NSNull null], @"null",
                nil
            ];

            it(@"should partition", ^{
                __block id failedObjects = nil;
                expect([dictionary filterEntriesWithFailedEntries:&failedObjects usingBlock:filterBlock]).toEqual(filteredDictionary);
                expect(failedObjects).toEqual(failedDictionary);
            });

            it(@"should partition concurrently", ^{
                __block id failedObjects = nil;
                expect([dictionary filterEntriesWithOptions:NSEnumerationConcurrent failedEntries:&failedObjects usingBlock:filterBlock]).toEqual(filteredDictionary);
                expect(failedObjects).toEqual(failedDictionary);
            });

            it(@"should partition in reverse", ^{
                __block id failedObjects = nil;
                expect([dictionary filterEntriesWithOptions:NSEnumerationReverse failedEntries:&failedObjects usingBlock:filterBlock]).toEqual(filteredDictionary);
                expect(failedObjects).toEqual(failedDictionary);
            });

            it(@"should partition even without failed entries", ^{
                expect([dictionary filterEntriesWithFailedEntries:NULL usingBlock:filterBlock]).toEqual(filteredDictionary);
            });

            it(@"should partition to empty dictionary", ^{
                __block id failedObjects;
                expect([[NSDictionary dictionary] filterEntriesWithFailedEntries:&failedObjects usingBlock:filterBlock]).toEqual([NSDictionary dictionary]);
                expect(failedObjects).toEqual([NSDictionary dictionary]);
            });
        });

        id unsuccessfulFilterBlock = ^(id key, id value){
            return NO;
        };

        it(@"should filter to empty dictionary when not successful", ^{
            expect([dictionary filterEntriesUsingBlock:unsuccessfulFilterBlock]).toEqual([NSDictionary dictionary]);
        });

        it(@"should partition to empty dictionary when not successful", ^{
            __block id failedObjects = nil;
            expect([dictionary filterEntriesWithFailedEntries:&failedObjects usingBlock:unsuccessfulFilterBlock]).toEqual([NSDictionary dictionary]);
            expect(failedObjects).toEqual(dictionary);
        });

        it(@"should return empty failed dictionary from partition when completely successful", ^{
            id successfulFilterBlock = ^(id key, id value){
                return YES;
            };

            __block id failedObjects = nil;
            expect([dictionary filterEntriesWithFailedEntries:&failedObjects usingBlock:successfulFilterBlock]).toEqual(dictionary);
            expect(failedObjects).toEqual([NSDictionary dictionary]);
        });

        describe(@"successful mapping", ^{
            id mapBlock = ^ id (id key, id value){
                if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"ba"])
                    return [value stringByAppendingString:@"buzz"];
                else
                    return [NSNull null];
            };

            NSDictionary *mappedDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNull null], @"foo",
                [NSNull null], @"buzz",
                [NSNull null], [NSNumber numberWithInt:20],
                @"buzzbuzz", @"baz",
                @"foobuzz", @"bar",
                [NSNull null], @"null",
                nil
            ];

            it(@"should map", ^{
                expect([dictionary mapValuesUsingBlock:mapBlock]).toEqual(mappedDictionary);
            });

            it(@"should map concurrently", ^{
                expect([dictionary mapValuesWithOptions:NSEnumerationConcurrent usingBlock:mapBlock]).toEqual(mappedDictionary);
            });

            it(@"should map in reverse", ^{
                expect([dictionary mapValuesWithOptions:NSEnumerationReverse usingBlock:mapBlock]).toEqual(mappedDictionary);
            });

            it(@"should map to empty dictionary", ^{
                expect([[NSDictionary dictionary] mapValuesUsingBlock:mapBlock]).toEqual([NSDictionary dictionary]);
            });
        });

        it(@"should remove elements when mapping block returns nil", ^{
            id removingMapBlock = ^(id key, id value){
                if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"b"])
                    return [@"buzz" stringByAppendingString:value];
                else
                    return nil;
            };

            NSDictionary *mappedDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                @"buzzbar", @"buzz",
                @"buzzbuzz", @"baz",
                @"buzzfoo", @"bar",
                nil
            ];

            expect([dictionary mapValuesUsingBlock:removingMapBlock]).toEqual(mappedDictionary);
        });

        describe(@"folding", ^{
            id foldBlock = ^(NSString *soFar, id nextKey, NSString *nextValue){
                if (![nextKey isKindOfClass:[NSString class]])
                    return soFar;

                if (![nextValue isKindOfClass:[NSString class]])
                    nextValue = @"null";

                if ([nextValue compare:soFar options:0 range:NSMakeRange(1, nextValue.length - 1)] == NSOrderedDescending)
                    return [nextValue substringFromIndex:1];
                else
                    return soFar;
            };

            NSString *startingValue = @"aaaa";
            NSString *result = @"uzz";

            it(@"should fold", ^{
                expect([dictionary foldEntriesWithValue:startingValue usingBlock:foldBlock]).toEqual(result);
            });

            it(@"should with nil", ^{
                expect([dictionary foldEntriesWithValue:nil usingBlock:foldBlock]).toEqual(result);
            });

            it(@"should fold to starting value", ^{
                expect([[NSDictionary dictionary] foldEntriesWithValue:startingValue usingBlock:foldBlock]).toEqual(startingValue);
            });
        });

        describe(@"successful key of entry passing test", ^{
            id testBlock = ^(id key, id value, BOOL *stop){
                return [value isKindOfClass:[NSNumber class]];
            };

            id key = [NSNumber numberWithInt:20];

            it(@"should return key passing test", ^{
                expect([dictionary keyOfEntryPassingTest:testBlock]).toEqual(key);
            });

            it(@"should return key passing test concurrently", ^{
                expect([dictionary keyOfEntryWithOptions:NSEnumerationConcurrent passingTest:testBlock]).toEqual(key);
            });

            it(@"should return key passing test in reverse", ^{
                expect([dictionary keyOfEntryWithOptions:NSEnumerationReverse passingTest:testBlock]).toEqual(key);
            });
        });
        
        it(@"should not return a key when testing empty dictionary", ^{
            id testBlock = ^(id key, id value, BOOL *stop){
                return YES;
            };

            expect([[NSDictionary dictionary] keyOfEntryPassingTest:testBlock]).toBeNil();
        });

        it(@"should not return a key when entry test fails", ^{
            id testBlock = ^(id key, id value, BOOL *stop){
                return [key isEqual:@"quux"];
            };

            expect([dictionary keyOfEntryPassingTest:testBlock]).toBeNil();
        });

        it(@"should not return a key when stopping test", ^{
            __block BOOL firstRun = YES;

            id testBlock = ^(id key, id value, BOOL *stop){
                expect(firstRun).toBeTruthy();

                firstRun = NO;

                *stop = YES;
                return NO;
            };

            expect([dictionary keyOfEntryPassingTest:testBlock]).toBeNil();
        });
    });

    id filterBlock = ^(NSString *str){
        return [str isEqualToString:@"bar"] || [str hasSuffix:@"zz"];
    };

    id mapBlock = ^(NSString *str){
        return [str stringByAppendingString:@"buzz"];
    };

    id orderedTestBlock = ^(NSString *str, NSUInteger index, BOOL *stop){
        return [str hasPrefix:@"ba"];
    };

    id unorderedTestBlock = ^(NSString *str, BOOL *stop){
        return [str isEqualToString:@"foo"];
    };

    id leftFoldBlock = ^(NSString *soFar, NSString *next){
        if ([next compare:soFar options:0 range:NSMakeRange(1, next.length - 1)] == NSOrderedDescending)
            return [next substringFromIndex:1];
        else
            return soFar;
    };

    id rightFoldBlock = ^(NSString *next, NSString *soFar){
        return [soFar stringByAppendingString:[next substringWithRange:NSMakeRange(1, 1)]];
    };

    describe(@"non-empty collection", ^{
        NSArray *array = [NSArray arrayWithObjects:@"foo", @"bar", @"baz", @"buzz", nil];
        NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"bar", @"baz", @"bizz", nil];
        NSSet *set = [NSSet setWithObjects:@"foo", @"bar", @"baz", @"bozz", nil];

        describe(@"successful filtering", ^{
            NSArray *filteredArray = [NSArray arrayWithObjects:@"bar", @"buzz", nil];
            NSArray *failedArray = [NSArray arrayWithObjects:@"foo", @"baz", nil];

            NSOrderedSet *filteredOrderedSet = [NSOrderedSet orderedSetWithObjects:@"bar", @"bizz", nil];
            NSOrderedSet *failedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foo", @"baz", nil];

            NSSet *filteredSet = [NSSet setWithObjects:@"bar", @"bozz", nil];
            NSSet *failedSet = [NSSet setWithObjects:@"foo", @"baz", nil];

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

            it(@"should partition even without failed objects", ^{
                expect([array filterWithFailedObjects:NULL usingBlock:filterBlock]).toEqual(filteredArray);
                expect([orderedSet filterWithFailedObjects:NULL usingBlock:filterBlock]).toEqual(filteredOrderedSet);
                expect([set filterWithFailedObjects:NULL usingBlock:filterBlock]).toEqual(filteredSet);
            });

            it(@"should partition", ^{
                __block id failedObjects = nil;

                expect([array filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredArray);
                expect(failedObjects).toEqual(failedArray);

                expect([orderedSet filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredOrderedSet);
                expect(failedObjects).toEqual(failedOrderedSet);

                expect([set filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredSet);
                expect(failedObjects).toEqual(failedSet);
            });

            it(@"should partition concurrently", ^{
                __block id failedObjects = nil;

                expect([array filterWithOptions:NSEnumerationConcurrent failedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredArray);
                expect(failedObjects).toEqual(failedArray);

                expect([orderedSet filterWithOptions:NSEnumerationConcurrent failedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredOrderedSet);
                expect(failedObjects).toEqual(failedOrderedSet);

                expect([set filterWithOptions:NSEnumerationConcurrent failedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredSet);
                expect(failedObjects).toEqual(failedSet);
            });

            it(@"should partition in reverse", ^{
                __block id failedObjects = nil;

                expect([array filterWithOptions:NSEnumerationReverse failedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredArray.reverseObjectEnumerator.allObjects);
                expect(failedObjects).toEqual(failedArray.reverseObjectEnumerator.allObjects);

                expect([[orderedSet filterWithOptions:NSEnumerationReverse failedObjects:&failedObjects usingBlock:filterBlock] allObjects]).toEqual(filteredOrderedSet.reverseObjectEnumerator.allObjects);
                expect([failedObjects allObjects]).toEqual(failedOrderedSet.reverseObjectEnumerator.allObjects);

                expect([set filterWithOptions:NSEnumerationReverse failedObjects:&failedObjects usingBlock:filterBlock]).toEqual(filteredSet);
                expect(failedObjects).toEqual(failedSet);
            });
        });

        id unsuccessfulFilterBlock = ^(id obj){
            return NO;
        };

        it(@"should filter to empty collection when not successful", ^{
            expect([array filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSArray array]);
            expect([orderedSet filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSOrderedSet orderedSet]);
            expect([set filterUsingBlock:unsuccessfulFilterBlock]).toEqual([NSSet set]);
        });

        it(@"should partition to empty collection when not successful", ^{
            __block id failedObjects = nil;

            expect([array filterWithFailedObjects:&failedObjects usingBlock:unsuccessfulFilterBlock]).toEqual([NSArray array]);
            expect(failedObjects).toEqual(array);

            expect([orderedSet filterWithFailedObjects:&failedObjects usingBlock:unsuccessfulFilterBlock]).toEqual([NSOrderedSet orderedSet]);
            expect(failedObjects).toEqual(orderedSet);

            expect([set filterWithFailedObjects:&failedObjects usingBlock:unsuccessfulFilterBlock]).toEqual([NSSet set]);
            expect(failedObjects).toEqual(set);
        });

        it(@"should return empty failed objects from partition when completely successful", ^{
            id successfulFilterBlock = ^(id obj){
                return YES;
            };

            __block id failedObjects = nil;

            expect([array filterWithFailedObjects:&failedObjects usingBlock:successfulFilterBlock]).toEqual(array);
            expect(failedObjects).toEqual([NSArray array]);

            expect([orderedSet filterWithFailedObjects:&failedObjects usingBlock:successfulFilterBlock]).toEqual(orderedSet);
            expect(failedObjects).toEqual([NSOrderedSet orderedSet]);

            expect([set filterWithFailedObjects:&failedObjects usingBlock:successfulFilterBlock]).toEqual(set);
            expect(failedObjects).toEqual([NSSet set]);
        });

        describe(@"successful mapping", ^{
            NSArray *mappedArray = [NSArray arrayWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", @"buzzbuzz", nil];
            NSOrderedSet *mappedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", @"bizzbuzz", nil];
            NSSet *mappedSet = [NSSet setWithObjects:@"foobuzz", @"barbuzz", @"bazbuzz", @"bozzbuzz", nil];

            it(@"should map", ^{
                expect([array mapUsingBlock:mapBlock]).toEqual(mappedArray);
                expect([orderedSet mapUsingBlock:mapBlock]).toEqual(mappedOrderedSet);
                expect([set mapUsingBlock:mapBlock]).toEqual(mappedSet);
            });

            it(@"should map concurrently", ^{
                expect([array mapWithOptions:NSEnumerationConcurrent usingBlock:mapBlock]).toEqual(mappedArray);
                expect([orderedSet mapWithOptions:NSEnumerationConcurrent usingBlock:mapBlock]).toEqual(mappedOrderedSet);
                expect([set mapWithOptions:NSEnumerationConcurrent usingBlock:mapBlock]).toEqual(mappedSet);
            });

            it(@"should map in reverse", ^{
                expect([array mapWithOptions:NSEnumerationReverse usingBlock:mapBlock]).toEqual(mappedArray.reverseObjectEnumerator.allObjects);
                expect([[orderedSet mapWithOptions:NSEnumerationReverse usingBlock:mapBlock] allObjects]).toEqual(mappedOrderedSet.reverseObjectEnumerator.allObjects);
                expect([set mapWithOptions:NSEnumerationReverse usingBlock:mapBlock]).toEqual(mappedSet);
            });

            it(@"should remove elements when mapping block returns nil", ^{
                id removingMapBlock = ^(NSString *str){
                    if ([str hasPrefix:@"ba"])
                        return [str stringByAppendingString:@"buzz"];
                    else
                        return nil;
                };

                id correspondingFilterBlock = ^(NSString *str){
                    return [str hasPrefix:@"ba"];
                };

                expect([array mapUsingBlock:removingMapBlock]).toEqual([mappedArray filterUsingBlock:correspondingFilterBlock]);
                expect([orderedSet mapUsingBlock:removingMapBlock]).toEqual([mappedOrderedSet filterUsingBlock:correspondingFilterBlock]);
                expect([set mapUsingBlock:removingMapBlock]).toEqual([mappedSet filterUsingBlock:correspondingFilterBlock]);
            });
        });

        it(@"should remove all elements when mapping block always returns nil", ^{
            id removingMapBlock = ^(NSString *str){
                return nil;
            };

            expect([array mapUsingBlock:removingMapBlock]).toEqual([NSArray array]);
            expect([orderedSet mapUsingBlock:removingMapBlock]).toEqual([NSOrderedSet orderedSet]);
            expect([set mapUsingBlock:removingMapBlock]).toEqual([NSSet set]);
        });

        describe(@"successful object passing test", ^{
            NSUInteger arrayIndex = [array indexOfObject:@"bar"];
            NSUInteger orderedSetIndex = [orderedSet indexOfObject:@"bar"];
            NSString *unorderedObject = @"foo";

            it(@"should return object passing test", ^{
                expect([array objectPassingTest:orderedTestBlock]).toEqual([array objectAtIndex:arrayIndex]);
                expect([orderedSet objectPassingTest:orderedTestBlock]).toEqual([orderedSet objectAtIndex:orderedSetIndex]);
                expect([set objectPassingTest:unorderedTestBlock]).toEqual(unorderedObject);
            });

            it(@"should return object passing test concurrently", ^{
                expect([array objectWithOptions:NSEnumerationConcurrent passingTest:orderedTestBlock]).toEqual([array objectAtIndex:arrayIndex]);
                expect([orderedSet objectWithOptions:NSEnumerationConcurrent passingTest:orderedTestBlock]).toEqual([orderedSet objectAtIndex:orderedSetIndex]);
                expect([set objectWithOptions:NSEnumerationConcurrent passingTest:unorderedTestBlock]).toEqual(unorderedObject);
            });

            it(@"should return object passing test in reverse", ^{
                expect([array objectWithOptions:NSEnumerationReverse passingTest:orderedTestBlock]).toEqual([array objectAtIndex:array.count - arrayIndex - 1]);
                expect([orderedSet objectWithOptions:NSEnumerationReverse passingTest:orderedTestBlock]).toEqual([orderedSet objectAtIndex:orderedSet.count - orderedSetIndex - 1]);
                expect([set objectWithOptions:NSEnumerationReverse passingTest:unorderedTestBlock]).toEqual(unorderedObject);
            });
        });

        it(@"should not return object passing test when test fails", ^{
            id orderedTestBlock = ^(NSString *str, NSUInteger index, BOOL *stop){
                return [str hasPrefix:@"quu"];
            };

            id unorderedTestBlock = ^(NSString *str, BOOL *stop){
                return [str hasPrefix:@"quu"];
            };

            expect([array objectPassingTest:orderedTestBlock]).toBeNil();
            expect([orderedSet objectPassingTest:orderedTestBlock]).toBeNil();
            expect([set objectPassingTest:unorderedTestBlock]).toBeNil();
        });

        it(@"should not return object passing test when stopping test", ^{
            id orderedTestBlock = ^(NSString *str, NSUInteger index, BOOL *stop){
                *stop = YES;
                return [str hasPrefix:@"ba"];
            };

            id unorderedTestBlock = ^(NSString *str, BOOL *stop){
                *stop = YES;

                // assume that -anyObject will return the "first" object that we
                // would be testing, and thus we should only match every other
                // object in the set
                return ![str isEqualToString:[set anyObject]];
            };
            
            expect([array objectPassingTest:orderedTestBlock]).toBeNil();
            expect([orderedSet objectPassingTest:orderedTestBlock]).toBeNil();
            expect([set objectPassingTest:unorderedTestBlock]).toBeNil();
        });

        describe(@"successful left folding", ^{
            NSString *startingValue = @"aaaa";

            NSString *arrayResult = @"uzz";
            NSString *orderedSetResult = @"oo";
            NSString *setResult = @"ozz";

            it(@"should fold", ^{
                expect([array foldLeftWithValue:startingValue usingBlock:leftFoldBlock]).toEqual(arrayResult);
                expect([orderedSet foldLeftWithValue:startingValue usingBlock:leftFoldBlock]).toEqual(orderedSetResult);
                expect([set foldWithValue:startingValue usingBlock:leftFoldBlock]).toEqual(setResult);
            });

            it(@"should fold with nil", ^{
                expect([array foldLeftWithValue:nil usingBlock:leftFoldBlock]).toEqual(arrayResult);
                expect([orderedSet foldLeftWithValue:nil usingBlock:leftFoldBlock]).toEqual(orderedSetResult);
                expect([set foldWithValue:nil usingBlock:leftFoldBlock]).toEqual(setResult);
            });
        });

        it(@"should right fold", ^{
            NSString *startingValue = @"A";

            NSString *arrayResult = @"Auaao";
            NSString *orderedSetResult = @"Aiaao";

            expect([array foldRightWithValue:startingValue usingBlock:rightFoldBlock]).toEqual(arrayResult);
            expect([orderedSet foldRightWithValue:startingValue usingBlock:rightFoldBlock]).toEqual(orderedSetResult);
        });

        it(@"should right fold with nil", ^{
            expect([array foldRightWithValue:nil usingBlock:rightFoldBlock]).toBeNil();
            expect([orderedSet foldRightWithValue:nil usingBlock:rightFoldBlock]).toBeNil();
        });
    });

    describe(@"empty collection", ^{
        it(@"should filter to empty collection", ^{
            expect([[NSArray array] filterUsingBlock:filterBlock]).toEqual([NSArray array]);
            expect([[NSOrderedSet orderedSet] filterUsingBlock:filterBlock]).toEqual([NSOrderedSet orderedSet]);
            expect([[NSSet set] filterUsingBlock:filterBlock]).toEqual([NSSet set]);
        });

        it(@"should partition to empty collection", ^{
            __block id failedObjects = nil;
            expect([[NSArray array] filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual([NSArray array]);
            expect(failedObjects).toEqual([NSArray array]);

            expect([[NSOrderedSet orderedSet] filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual([NSOrderedSet orderedSet]);
            expect(failedObjects).toEqual([NSOrderedSet orderedSet]);

            expect([[NSSet set] filterWithFailedObjects:&failedObjects usingBlock:filterBlock]).toEqual([NSSet set]);
            expect(failedObjects).toEqual([NSSet set]);
        });

        it(@"should map to empty collection", ^{
            expect([[NSArray array] mapUsingBlock:mapBlock]).toEqual([NSArray array]);
            expect([[NSOrderedSet orderedSet] mapUsingBlock:mapBlock]).toEqual([NSOrderedSet orderedSet]);
            expect([[NSSet set] mapUsingBlock:mapBlock]).toEqual([NSSet set]);
        });

        it(@"should not return object passing test", ^{
            expect([[NSArray array] objectPassingTest:orderedTestBlock]).toBeNil();
            expect([[NSOrderedSet orderedSet] objectPassingTest:orderedTestBlock]).toBeNil();
            expect([[NSSet set] objectPassingTest:unorderedTestBlock]).toBeNil();
        });

        it(@"should fold left to starting value", ^{
            id value = @"foobar";

            expect([[NSArray array] foldLeftWithValue:value usingBlock:leftFoldBlock]).toEqual(value);
            expect([[NSOrderedSet orderedSet] foldLeftWithValue:value usingBlock:leftFoldBlock]).toEqual(value);
            expect([[NSSet set] foldWithValue:value usingBlock:leftFoldBlock]).toEqual(value);
        });

        it(@"should fold right to starting value", ^{
            id value = @"foobar";

            expect([[NSArray array] foldRightWithValue:value usingBlock:rightFoldBlock]).toEqual(value);
            expect([[NSOrderedSet orderedSet] foldRightWithValue:value usingBlock:rightFoldBlock]).toEqual(value);
        });
    });

SpecEnd
