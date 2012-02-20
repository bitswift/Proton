//
//  PROTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

@interface TransformationTestModel : PROModel
@property (nonatomic, copy) NSArray *array;
@end

// implements KVC mutable to-many accessors for an "items" key, but doesn't
// provide an actual property
@interface TransformationInPlaceTestObject : NSObject {
@public
    NSMutableArray *m_items;
}

@end

SpecBegin(PROTransformation)
    __block id transformation = nil;
    __block void (^verifyTransformation)(void);

    before(^{
        verifyTransformation = nil;
    });

    after(^{
        if (verifyTransformation) {
            verifyTransformation();

            // the transformation and the flattened transformation should have the
            // same effect
            transformation = [transformation flattenedTransformation];
            verifyTransformation();
        }
    });

    describe(@"unique transformation", ^{
        NSString *uniqueInputValue = @"inputValue";
        NSString *uniqueOutputValue = @"outputValue";

        after(^{
            // a unique transformation should not have any child transformations
            expect([transformation transformations]).toBeNil();
        });

        it(@"initializes without any values", ^{
            transformation = [[PROUniqueTransformation alloc] init];
            expect(transformation).not.toBeNil();

            expect([transformation inputValue]).toBeNil();
            expect([transformation outputValue]).toBeNil();

            // values should just pass through
            verifyTransformation = [^{
                __block NSError *error = nil;
                expect([transformation transform:uniqueInputValue error:&error]).toEqual(uniqueInputValue);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes and copies values", ^{
            NSMutableString *mutableInputValue = [[NSMutableString alloc] initWithString:uniqueInputValue];
            NSMutableString *mutableOutputValue = [[NSMutableString alloc] initWithString:uniqueOutputValue];

            transformation = [[PROUniqueTransformation alloc] initWithInputValue:mutableInputValue outputValue:mutableOutputValue];

            expect([transformation inputValue]).toEqual(mutableInputValue);
            expect([transformation outputValue]).toEqual(mutableOutputValue);
            
            [mutableInputValue appendString:@"foo"];
            [mutableOutputValue appendString:@"bar"];

            // the strings on 'transformation' should be untouched, even though we
            // modified the originals
            expect([transformation inputValue]).not.toEqual(mutableInputValue);
            expect([transformation outputValue]).not.toEqual(mutableOutputValue);
        });

        it(@"converts nil input value to NSNull", ^{
            transformation = [[PROUniqueTransformation alloc] initWithInputValue:nil outputValue:uniqueOutputValue];
            expect(transformation).not.toBeNil();

            expect([transformation inputValue]).toEqual([NSNull null]);
        });

        it(@"converts nil output value to NSNull", ^{
            transformation = [[PROUniqueTransformation alloc] initWithInputValue:uniqueInputValue outputValue:nil];
            expect(transformation).not.toBeNil();

            expect([transformation outputValue]).toEqual([NSNull null]);
        });

        describe(@"with values", ^{
            before(^{
                transformation = [[PROUniqueTransformation alloc] initWithInputValue:uniqueInputValue outputValue:uniqueOutputValue];
                expect(transformation).not.toBeNil();
            });

            it(@"should be equal to another transformation initialized with same values", ^{
                PROTransformation *equalTransformation = [[PROUniqueTransformation alloc] initWithInputValue:uniqueInputValue outputValue:uniqueOutputValue];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should match values given at initialization", ^{
                expect([transformation inputValue]).toEqual(uniqueInputValue);
                expect([transformation outputValue]).toEqual(uniqueOutputValue);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:uniqueInputValue error:&error]).toEqual(uniqueOutputValue);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform another value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:uniqueOutputValue error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = uniqueInputValue;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(uniqueOutputValue);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform another value to the output value in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = uniqueOutputValue;

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual(uniqueOutputValue);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROUniqueTransformation *reverseTransformation = (id)[transformation reverseTransformation];
                    expect(reverseTransformation.inputValue).toEqual(uniqueOutputValue);
                    expect(reverseTransformation.outputValue).toEqual(uniqueInputValue);

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:uniqueOutputValue error:&error]).toEqual(uniqueInputValue);
                    expect(error).toBeNil();
                } copy];
            });
        });
    });

    describe(@"indexed transformation", ^{
        NSArray *startArray = [NSArray arrayWithObjects:
            [NSNull null],
            [NSNumber numberWithInt:5],
            [NSNumber numberWithInt:5],
            @"foo",
            nil
        ];

        NSArray *endArray = [NSArray arrayWithObjects:
            [NSNull null],
            [NSNumber numberWithBool:NO],
            [NSNumber numberWithInt:5],
            @"bar",
            nil
        ];

        it(@"initializes without transformations", ^{
            transformation = [[PROIndexedTransformation alloc] init];
            expect(transformation).not.toBeNil();

            expect([transformation indexes]).toBeNil();
            expect([transformation transformations]).toEqual([NSArray array]);

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes with a single index", ^{
            PROUniqueTransformation *transformationAtIndex = [[PROUniqueTransformation alloc] init];

            transformation = [[PROIndexedTransformation alloc] initWithIndex:3 transformation:transformationAtIndex];
            expect(transformation).not.toBeNil();

            expect([transformation indexes]).toEqual([NSIndexSet indexSetWithIndex:3]);
            expect([transformation transformations]).toEqual([NSArray arrayWithObject:transformationAtIndex]);
        });

        describe(@"with transformations", ^{
            __block NSIndexSet *indexes;
            __block NSArray *transformations;

            before(^{
                NSMutableIndexSet *mutableIndexes = [[NSMutableIndexSet alloc] init];
                [mutableIndexes addIndex:1];
                [mutableIndexes addIndex:3];
                indexes = mutableIndexes;

                NSMutableArray *mutableTransformations = [[NSMutableArray alloc] init];

                {
                    // array[1] = 5 -> NO

                    id inputValue = [NSNumber numberWithInt:5];
                    id outputValue = [NSNumber numberWithBool:NO];
                    PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:inputValue outputValue:outputValue];

                    [mutableTransformations addObject:transformation];
                }

                {
                    // array[3] = "foo" -> "bar"

                    id inputValue = @"foo";
                    id outputValue = @"bar";
                    PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:inputValue outputValue:outputValue];

                    [mutableTransformations addObject:transformation];
                }

                transformations = mutableTransformations;

                transformation = [[PROIndexedTransformation alloc] initWithIndexes:indexes transformations:transformations];
                expect(transformation).not.toBeNil();
            });

            it(@"should match indexes and transformations given at initialization", ^{
                expect([transformation indexes]).toEqual(indexes);
                expect([transformation transformations]).toEqual(transformations);
            });

            it(@"should be equal to another transformation initialized with same transformations", ^{
                PROTransformation *equalTransformation = [[PROIndexedTransformation alloc] initWithIndexes:indexes transformations:transformations];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:startArray error:&error]).toEqual(endArray);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform out of bounds indexes", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    NSMutableArray *mutableArray = [startArray mutableCopy];

                    __block NSError *error = nil;
                    __block id value = mutableArray;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(endArray);
                    expect(error).toBeNil();

                    // the transformation should've mutated the array, not created
                    // a new one
                    expect(mutableArray).toEqual(endArray);
                } copy];
            });

            it(@"should not transform out of bounds indexes in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = [NSArray array];

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual([NSArray array]);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                    expect(error).toBeNil();
                } copy];
            });
        });

        describe(@"nested array transformations in place", ^{
            __block PROTransformation *arrayTransformation;

            before(^{
                arrayTransformation = nil;
            });

            after(^{
                expect(arrayTransformation).not.toBeNil();

                verifyTransformation = [^{
                    NSMutableArray *items = [NSMutableArray arrayWithObject:@"foobar"];
                    __block NSMutableArray *array = [NSMutableArray arrayWithObject:items];

                    NSArray *expectedArray = [arrayTransformation transform:items error:NULL];
                    expect(expectedArray).not.toBeNil();

                    transformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:arrayTransformation];
                    expect(transformation).not.toBeNil();
        
                    __block NSError *error = nil;
                    expect([transformation transformInPlace:&array error:&error]).toBeTruthy();
                    expect(error).toBeNil();

                    expect([array objectAtIndex:0]).toEqual(expectedArray);

                    // should've mutated the array, not created a new one
                    expect(items).toEqual(expectedArray);
                } copy];
            });

            it(@"should perform an indexed transformation in place at the index", ^{
                PROTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foobar" outputValue:@"fizzbuzz"];
                arrayTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:uniqueTransformation];
            });

            it(@"should perform an insertion transformation in place at the index", ^{
                arrayTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:1 object:@"fizzbuzz"];
            });

            it(@"should perform a removal transformation in place at the index", ^{
                arrayTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:@"foobar"];
            });
        });
    });

    describe(@"insertion transformation", ^{
        NSArray *startArray = [NSArray arrayWithObjects:
            [NSNull null],
            [NSNumber numberWithInt:5],
            @"foo",
            nil
        ];

        NSArray *endArray = [NSArray arrayWithObjects:
            [NSNull null],
            [NSNumber numberWithBool:NO],
            @"bar",
            [NSNumber numberWithInt:5],
            @"foo",
            nil
        ];

        it(@"initializes without objects", ^{
            transformation = [[PROInsertionTransformation alloc] init];
            expect(transformation).not.toBeNil();
            expect([transformation transformations]).toBeNil();

            expect([transformation insertionIndexes]).toBeNil();
            expect([transformation objects]).toBeNil();

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes with a single index", ^{
            transformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:3 object:@"foobar"];
            expect(transformation).not.toBeNil();
            expect([transformation transformations]).toBeNil();

            expect([transformation insertionIndexes]).toEqual([NSIndexSet indexSetWithIndex:3]);
            expect([transformation objects]).toEqual([NSArray arrayWithObject:@"foobar"]);
        });

        it(@"should insert into empty array", ^{
            transformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:@"foobar"];

            verifyTransformation = [^{
                __block NSError *error = nil;
                expect([transformation transform:[NSArray array] error:&error]).toEqual([NSArray arrayWithObject:@"foobar"]);
                expect(error).toBeNil();
            } copy];
        });

        describe(@"with objects", ^{
            NSArray *objects = [NSArray arrayWithObjects:
                [NSNumber numberWithBool:NO],
                @"bar",
                nil
            ];

            __block NSIndexSet *indexes;

            before(^{
                NSMutableIndexSet *mutableIndexes = [[NSMutableIndexSet alloc] init];

                // insert(array[1], NO)
                [mutableIndexes addIndex:1];

                // insert(array[2], "bar")
                [mutableIndexes addIndex:2];

                indexes = mutableIndexes;

                transformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:indexes objects:objects];
                expect(transformation).not.toBeNil();
            });

            it(@"should match indexes and objects given at initialization", ^{
                expect([transformation insertionIndexes]).toEqual(indexes);
                expect([transformation objects]).toEqual(objects);
            });

            it(@"should be equal to another transformation initialized with same objects", ^{
                PROTransformation *equalTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndexes:indexes objects:objects];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:startArray error:&error]).toEqual(endArray);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform out of bounds indexes", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    NSMutableArray *mutableArray = [startArray mutableCopy];

                    __block NSError *error = nil;
                    __block id value = mutableArray;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(endArray);
                    expect(error).toBeNil();

                    // the transformation should've mutated the array, not created
                    // a new one
                    expect(mutableArray).toEqual(endArray);
                } copy];
            });

            it(@"should not transform out of bounds indexes in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = [NSArray array];

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual([NSArray array]);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                    expect(error).toBeNil();
                } copy];
            });
        });
    });

    describe(@"removal transformation", ^{
        NSArray *startArray = [NSArray arrayWithObjects:
            [NSNull null],
            [NSNumber numberWithBool:NO],
            [NSNumber numberWithInt:5],
            @"foo",
            @"bar",
            nil
        ];

        NSArray *endArray = [NSArray arrayWithObjects:
            [NSNumber numberWithInt:5],
            @"foo",
            nil
        ];

        it(@"initializes without objects", ^{
            transformation = [[PRORemovalTransformation alloc] init];
            expect(transformation).not.toBeNil();
            expect([transformation transformations]).toBeNil();

            expect([transformation removalIndexes]).toBeNil();
            expect([transformation expectedObjects]).toBeNil();

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes with a single index", ^{
            transformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:3 expectedObject:@"foobar"];
            expect(transformation).not.toBeNil();
            expect([transformation transformations]).toBeNil();

            expect([transformation removalIndexes]).toEqual([NSIndexSet indexSetWithIndex:3]);
            expect([transformation expectedObjects]).toEqual([NSArray arrayWithObject:@"foobar"]);
        });

        it(@"should remove down to an empty array", ^{
            transformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:@"foobar"];

            verifyTransformation = [^{
                __block NSError *error = nil;
                expect([transformation transform:[NSArray arrayWithObject:@"foobar"] error:&error]).toEqual([NSArray array]);
                expect(error).toBeNil();
            } copy];
        });

        describe(@"with objects", ^{
            NSArray *expectedObjects = [NSArray arrayWithObjects:
                [NSNull null],
                [NSNumber numberWithBool:NO],
                @"bar",
                nil
            ];

            __block NSIndexSet *indexes;

            before(^{
                NSMutableIndexSet *mutableIndexes = [[NSMutableIndexSet alloc] init];

                // remove(array[0], null)
                [mutableIndexes addIndex:0];

                // remove(array[1], NO)
                [mutableIndexes addIndex:1];

                // remove(array[4], "bar")
                [mutableIndexes addIndex:4];

                indexes = mutableIndexes;

                transformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexes expectedObjects:expectedObjects];
                expect(transformation).not.toBeNil();
            });

            it(@"should match indexes and objects given at initialization", ^{
                expect([transformation removalIndexes]).toEqual(indexes);
                expect([transformation expectedObjects]).toEqual(expectedObjects);
            });

            it(@"should be equal to another transformation initialized with same objects", ^{
                PROTransformation *equalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexes expectedObjects:expectedObjects];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:startArray error:&error]).toEqual(endArray);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform out of bounds indexes", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should not transform with mismatched objects", ^{
                NSMutableArray *modifiedStartArray = [startArray mutableCopy];
                [modifiedStartArray insertObject:@"fizzbuzz" atIndex:[indexes firstIndex]];

                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:modifiedStartArray error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    NSMutableArray *mutableArray = [startArray mutableCopy];

                    __block NSError *error = nil;
                    __block id value = mutableArray;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(endArray);
                    expect(error).toBeNil();

                    // the transformation should've mutated the array, not created
                    // a new one
                    expect(mutableArray).toEqual(endArray);
                } copy];
            });

            it(@"should not transform out of bounds indexes in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = [NSArray array];

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual([NSArray array]);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should not transform mismatched objects in place", ^{
                verifyTransformation = [^{
                    __block NSMutableArray *modifiedStartArray = [startArray mutableCopy];
                    [modifiedStartArray insertObject:@"fizzbuzz" atIndex:[indexes firstIndex]];

                    NSArray *expectedValue = [modifiedStartArray copy];

                    __block NSError *error = nil;
                    expect([transformation transformInPlace:&modifiedStartArray error:&error]).toBeFalsy();
                    expect(modifiedStartArray).toEqual(expectedValue);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                    expect(error).toBeNil();
                } copy];
            });
        });
    });

    describe(@"keyed transformation", ^{
        NSDictionary *startDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"bar", @"foo",
            [NSNull null], @"nil",
            [NSNumber numberWithBool:YES], @"5",
            nil
        ];

        NSDictionary *endDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"bar", @"foo",
            @"null", @"nil",
            [NSNumber numberWithBool:NO], @"5",
            nil
        ];

        it(@"initializes without transformations", ^{
            transformation = [[PROKeyedTransformation alloc] init];
            expect(transformation).not.toBeNil();

            expect([transformation valueTransformations]).toBeNil();
            expect([transformation transformations]).toEqual([NSArray array]);

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:startDictionary error:&error]).toEqual(startDictionary);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes with a single transformation", ^{
            PROUniqueTransformation *transformationForKey = [[PROUniqueTransformation alloc] init];

            transformation = [[PROKeyedTransformation alloc] initWithTransformation:transformationForKey forKey:@"foobar"];
            expect(transformation).not.toBeNil();

            expect([[transformation valueTransformations] count]).toEqual(1);
            expect([[transformation valueTransformations] objectForKey:@"foobar"]).toEqual(transformationForKey);
            expect([transformation transformations]).toEqual([NSArray arrayWithObject:transformationForKey]);
        });

        it(@"initializes with a key path", ^{
            PROUniqueTransformation *transformationForKey = [[PROUniqueTransformation alloc] init];

            transformation = [[PROKeyedTransformation alloc] initWithTransformation:transformationForKey forKeyPath:@"foobar.something"];
            expect(transformation).not.toBeNil();

            // should have Keyed "foobar" -> Keyed "something" -> Unique
            expect([[transformation valueTransformations] count]).toEqual(1);

            PROKeyedTransformation *somethingTransformation = [[transformation valueTransformations] objectForKey:@"foobar"];
            expect(somethingTransformation).not.toBeNil();

            expect([[somethingTransformation valueTransformations] count]).toEqual(1);
            expect([[somethingTransformation valueTransformations] objectForKey:@"something"]).toEqual(transformationForKey);
        });

        describe(@"with transformations", ^{
            __block NSDictionary *valueTransformations;

            before(^{
                NSMutableDictionary *transformations = [[NSMutableDictionary alloc] init];

                {
                    // for key "nil": NSNull -> @"null"
                    PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSNull null] outputValue:@"null"];
                    [transformations setObject:transformation forKey:@"nil"];
                }

                {
                    // for key "5": YES -> NO
                    PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSNumber numberWithBool:YES] outputValue:[NSNumber numberWithBool:NO]];
                    [transformations setObject:transformation forKey:@"5"];
                }

                // key "foo" is left unmodified

                valueTransformations = transformations;

                transformation = [[PROKeyedTransformation alloc] initWithValueTransformations:valueTransformations];
                expect(transformation).not.toBeNil();
            });

            it(@"should match transformations given at initialization", ^{
                expect([transformation valueTransformations]).toEqual(valueTransformations);
                expect([transformation transformations]).toEqual(valueTransformations.allValues);
            });

            it(@"should be equal to another transformation initialized with same transformations", ^{
                PROTransformation *equalTransformation = [[PROKeyedTransformation alloc] initWithValueTransformations:valueTransformations];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:startDictionary error:&error]).toEqual(endDictionary);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform an object which is not a <PROKeyedObject>", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:@"foobar" error:&error]).toBeNil();
                    expect(error).not.toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorUnsupportedInputType);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should treat missing values as NSNull", ^{
                NSMutableDictionary *modifiedStartDictionary = [startDictionary mutableCopy];

                // remove the key associated with NSNull
                [modifiedStartDictionary removeObjectForKey:@"nil"];

                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:modifiedStartDictionary error:&error]).toEqual(endDictionary);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    NSMutableDictionary *mutableStartDictionary = [startDictionary mutableCopy];

                    __block NSError *error = nil;
                    __block id value = mutableStartDictionary;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(endDictionary);
                    expect(error).toBeNil();

                    // the transformation should've mutated the dictionary, not
                    // created a new one
                    expect(mutableStartDictionary).toEqual(endDictionary);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:endDictionary error:&error]).toEqual(startDictionary);
                    expect(error).toBeNil();
                } copy];
            });
        });

        it(@"should transform custom class", ^{
            NSArray *endArray = [NSArray arrayWithObject:@"foobar"];
            PROUniqueTransformation *arrayTransformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSArray array] outputValue:endArray];

            TransformationTestModel *model = [[TransformationTestModel alloc] init];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:PROKeyForObject(model, array)];

            TransformationTestModel *expectedModel = [[TransformationTestModel alloc] init];
            expectedModel.array = endArray;

            verifyTransformation = [^{
                __block NSError *error = nil;
                expect([transformation transform:model error:&error]).toEqual(expectedModel);
                expect(error).toBeNil();
            } copy];
        });

        describe(@"array transformations in place", ^{
            __block PROTransformation *arrayTransformation;

            before(^{
                arrayTransformation = nil;
            });

            after(^{
                expect(arrayTransformation).not.toBeNil();

                verifyTransformation = [^{
                    __block TransformationInPlaceTestObject *model = [[TransformationInPlaceTestObject alloc] init];

                    NSMutableArray *items = model->m_items;
                    [items addObject:@"foobar"];

                    NSArray *expectedArray = [arrayTransformation transform:items error:NULL];
                    expect(expectedArray).not.toBeNil();

                    transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:@"items"];
                    expect(transformation).not.toBeNil();
        
                    __block NSError *error = nil;
                    expect([transformation transformInPlace:&model error:&error]).toBeTruthy();
                    expect(error).toBeNil();

                    expect(model->m_items).toEqual(expectedArray);

                    // should've mutated the array, not created a new one
                    expect(items).toEqual(expectedArray);
                } copy];
            });

            it(@"should perform an indexed transformation in place on the key", ^{
                PROTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foobar" outputValue:@"fizzbuzz"];
                arrayTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:uniqueTransformation];
            });

            it(@"should perform an insertion transformation in place on the key", ^{
                arrayTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:1 object:@"fizzbuzz"];
            });

            it(@"should perform a removal transformation in place on the key", ^{
                arrayTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:@"foobar"];
            });
        });
    });

    describe(@"multiple transformation", ^{
        NSString *multipleStartValue = @"startValue";
        NSString *multipleMiddleValue = @"middleValue";
        NSString *multipleEndValue = @"endValue";

        it(@"initializes without transformations", ^{
            transformation = [[PROMultipleTransformation alloc] init];
            expect(transformation).not.toBeNil();

            expect([transformation transformations]).toEqual([NSArray array]);

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:multipleStartValue error:&error]).toEqual(multipleStartValue);
                expect(error).toBeNil();
            } copy];
        });

        describe(@"with transformations", ^{
            __block NSArray *transformations = nil;

            before(^{
                transformations = [NSArray arrayWithObjects:
                    // start -> middle
                    [[PROUniqueTransformation alloc] initWithInputValue:multipleStartValue outputValue:multipleMiddleValue],
                    
                    // middle -> end
                    [[PROUniqueTransformation alloc] initWithInputValue:multipleMiddleValue outputValue:multipleEndValue],

                    nil
                ];

                transformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];
                expect(transformation).not.toBeNil();
            });

            it(@"should match transformations given at initialization", ^{
                expect([transformation transformations]).toEqual(transformations);
            });

            it(@"should be equal to another transformation initialized with same values", ^{
                PROTransformation *equalTransformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:multipleStartValue error:&error]).toEqual(multipleEndValue);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform another value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:multipleMiddleValue error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);

                    if ([transformation isKindOfClass:[PROMultipleTransformation class]]) {
                        // unflattened
                        NSArray *failingTransformations = [NSArray arrayWithObjects:transformation, [transformations objectAtIndex:0], nil];
                        expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual(failingTransformations);
                    } else {
                        // flattened
                        NSArray *failingTransformations = [NSArray arrayWithObject:transformation];
                        expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual(failingTransformations);
                    }
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = multipleStartValue;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(multipleEndValue);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform another value to the output value in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = multipleMiddleValue;

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual(multipleMiddleValue);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorMismatchedInput);

                    if ([transformation isKindOfClass:[PROMultipleTransformation class]]) {
                        // unflattened
                        NSArray *failingTransformations = [NSArray arrayWithObjects:transformation, [transformations objectAtIndex:0], nil];
                        expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual(failingTransformations);
                    } else {
                        // flattened
                        NSArray *failingTransformations = [NSArray arrayWithObject:transformation];
                        expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual(failingTransformations);
                    }
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:multipleEndValue error:&error]).toEqual(multipleStartValue);
                    expect(error).toBeNil();
                } copy];
            });
        });
    });

    describe(@"order transformation", ^{
        NSArray *startArray = [NSArray arrayWithObjects:
            @"foomove",
            @"bar",
            @"bazmove",
            @"buzz",
            @"blah",
            @"buzzmove",
            nil
        ];

        NSArray *endArray = [NSArray arrayWithObjects:
            @"bar",
            @"buzz",
            @"blah",
            @"foomove",
            @"bazmove",
            @"buzzmove",
            nil
        ];

        it(@"initializes without indexes", ^{
            transformation = [[PROOrderTransformation alloc] init];
            expect(transformation).not.toBeNil();

            expect([transformation startIndexes]).toBeNil();
            expect([transformation endIndexes]).toBeNil();
            expect([transformation transformations]).toBeNil();

            verifyTransformation = [^{
                // values should just pass through
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
            } copy];
        });

        it(@"initializes with single indexes", ^{
            transformation = [[PROOrderTransformation alloc] initWithStartIndex:2 endIndex:5];
            expect(transformation).not.toBeNil();

            expect([transformation startIndexes]).toEqual([NSIndexSet indexSetWithIndex:2]);
            expect([transformation endIndexes]).toEqual([NSIndexSet indexSetWithIndex:5]);
        });

        describe(@"with index sets", ^{
            __block NSIndexSet *startIndexes;
            __block NSIndexSet *endIndexes;

            before(^{
                NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
                [indexSet addIndex:0];
                [indexSet addIndex:2];
                [indexSet addIndex:5];
                startIndexes = indexSet;

                endIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(3, 3)];

                transformation = [[PROOrderTransformation alloc] initWithStartIndexes:startIndexes endIndexes:endIndexes];
                expect(transformation).not.toBeNil();
            });

            it(@"should match indexes given at initialization", ^{
                expect([transformation startIndexes]).toEqual(startIndexes);
                expect([transformation endIndexes]).toEqual(endIndexes);
            });

            it(@"should be equal to another transformation initialized with same indexes", ^{
                PROTransformation *equalTransformation = [[PROOrderTransformation alloc] initWithStartIndexes:startIndexes endIndexes:endIndexes];
                expect(equalTransformation).toEqual(transformation);
            });

            it(@"should transform the input value to the output value", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:startArray error:&error]).toEqual(endArray);
                    expect(error).toBeNil();
                } copy];
            });

            it(@"should not transform out of bounds indexes", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should transform the input value to the output value in place", ^{
                verifyTransformation = [^{
                    NSMutableArray *mutableArray = [startArray mutableCopy];

                    __block NSError *error = nil;
                    __block id value = mutableArray;

                    expect([transformation transformInPlace:&value error:&error]).toBeTruthy();
                    expect(value).toEqual(endArray);
                    expect(error).toBeNil();

                    // the transformation should've mutated the array, not created
                    // a new one
                    expect(mutableArray).toEqual(endArray);
                } copy];
            });

            it(@"should not transform out of bounds indexes in place", ^{
                verifyTransformation = [^{
                    __block NSError *error = nil;
                    __block id value = [NSArray array];

                    expect([transformation transformInPlace:&value error:&error]).toBeFalsy();
                    expect(value).toEqual([NSArray array]);

                    expect(error.domain).toEqual([PROTransformation errorDomain]);
                    expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                    expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
                } copy];
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                verifyTransformation = [^{
                    PROTransformation *reverseTransformation = [transformation reverseTransformation];

                    __block NSError *error = nil;
                    expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                    expect(error).toBeNil();
                } copy];
            });
        });
    });

    describe(@"applying blocks", ^{
        __block TransformationTestModel *model;
        __block NSMutableArray *mutableArray;
        __block NSDictionary *dictionary;

        __block NSMutableDictionary *blocks;
        __block BOOL newValueBlockInvoked;
        __block BOOL nestedNewValueBlockInvoked;

        __block void (^setupBlock)(void);

        before(^{
            dictionary = [NSDictionary dictionaryWithObject:@"foo" forKey:@"bar"];

            model = [[TransformationTestModel alloc] init];
            model.array = [NSArray arrayWithObject:dictionary];

            // these applied blocks have lots of side effects, so it's simpler
            // to make it all part of the verifyTransformation block that gets
            // called
            setupBlock = [^{
                newValueBlockInvoked = NO;
                nestedNewValueBlockInvoked = NO;

                mutableArray = [NSMutableArray arrayWithObject:dictionary];
                model.array = mutableArray;

                // this will only get invoked for top level or the 'array' property,
                // because we replace this block after diving down into the array
                id newValueBlock = [^(PROTransformation *localTransformation, id value, NSString *keyPath){
                    id transformedModel = [transformation transform:model error:NULL];

                    if (keyPath) {
                        expect(keyPath).toEqual(@"array");
                        expect(value).toEqual([transformedModel valueForKeyPath:keyPath]);
                        expect(localTransformation).not.toBeNil();
                    } else {
                        expect(value).toEqual(transformedModel);
                        expect(localTransformation).toBeKindOf([PROUniqueTransformation class]);
                    }

                    newValueBlockInvoked = YES;
                    return YES;
                } copy];

                id mutableArrayBlock = [^(PROTransformation *localTransformation, NSString *keyPath){
                    expect(keyPath).toEqual(@"array");
                    expect(localTransformation).not.toBeNil();

                    return mutableArray;
                } copy];

                id wrappedValueBlock = [^(PROTransformation *localTransformation, id value, NSString *keyPath){
                    expect(value).toBeKindOf([NSString class]);
                    expect(keyPath).toEqual(@"array");
                    expect(localTransformation).toBeKindOf([PROInsertionTransformation class]);

                    return [NSNull null];
                } copy];

                id blocksForIndexBlock = [^(PROTransformation *localTransformation, NSUInteger index, NSString *keyPath, NSDictionary *blocks){
                    id transformedModel = [transformation transform:model error:NULL];

                    expect(keyPath).toEqual(@"array");
                    expect(index).toEqual(0);
                    expect(localTransformation).toBeKindOf([PROIndexedTransformation class]);

                    PROTransformationNewValueForKeyPathBlock newValueBlock = [^(PROTransformation *localTransformation, id value, NSString *keyPath){
                        nestedNewValueBlockInvoked = YES;

                        expect(keyPath).not.toBeNil();
                        expect(localTransformation).not.toBeNil();

                        NSDictionary *transformedDictionary = [[transformedModel array] objectAtIndex:0];
                        expect(value).toEqual([transformedDictionary valueForKeyPath:keyPath]);

                        return YES;
                    } copy];

                    NSMutableDictionary *newBlocks = [blocks mutableCopy];
                    [newBlocks setObject:newValueBlock forKey:PROTransformationNewValueForKeyPathBlockKey];

                    return newBlocks;
                } copy];

                blocks = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                    newValueBlock, PROTransformationNewValueForKeyPathBlockKey,
                    mutableArrayBlock, PROTransformationMutableArrayForKeyPathBlockKey,
                    wrappedValueBlock, PROTransformationWrappedValueForKeyPathBlockKey,
                    blocksForIndexBlock, PROTransformationBlocksForIndexAtKeyPathBlockKey,
                    nil
                ];
            } copy];
        });

        it(@"should apply new value block at top level", ^{
            TransformationTestModel *newModel = [[TransformationTestModel alloc] init];
            transformation = [[PROUniqueTransformation alloc] initWithInputValue:model outputValue:newModel];

            verifyTransformation = [^{
                setupBlock();

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();
                expect(newValueBlockInvoked).toBeTruthy();
            } copy];
        });

        it(@"should apply new value block at array level", ^{
            transformation = [model transformationForKey:@"array" value:[NSArray array]];

            verifyTransformation = [^{
                setupBlock();

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();
                expect(newValueBlockInvoked).toBeTruthy();
                expect(mutableArray).not.toEqual(result.array);
            } copy];
        });

        it(@"should perform array mutations", ^{
            id expectedObject = [model.array objectAtIndex:0];

            PROTransformation *arrayTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:expectedObject];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:@"array"];

            verifyTransformation = [^{
                setupBlock();

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();
                expect(newValueBlockInvoked).toBeFalsy();
                expect(mutableArray).toEqual([NSArray array]);
            } copy];
        });

        it(@"should wrap inserted values", ^{
            NSString *insertedObject = @"foobar";

            PROTransformation *arrayTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:insertedObject];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:@"array"];

            verifyTransformation = [^{
                setupBlock();

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();
                expect(newValueBlockInvoked).toBeFalsy();

                // the inserted object should've been "wrapped" as an NSNull
                NSArray *expectedArray = [NSArray arrayWithObjects:[NSNull null], dictionary, nil];
                expect(mutableArray).toEqual(expectedArray);
            } copy];
        });

        it(@"should retrieve blocks for nested indexes", ^{
            PROUniqueTransformation *barTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:@"fizzbuzz"];
            PROKeyedTransformation *dictionaryTransformation = [[PROKeyedTransformation alloc] initWithTransformation:barTransformation forKey:@"bar"];

            PROTransformation *arrayTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:dictionaryTransformation];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:@"array"];

            verifyTransformation = [^{
                setupBlock();

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();
                expect(newValueBlockInvoked).toBeFalsy();
                expect(nestedNewValueBlockInvoked).toBeTruthy();
                expect(mutableArray).not.toEqual(result.array);
            } copy];
        });

        it(@"should fail to apply unique transformation if new value block fails", ^{
            TransformationTestModel *newModel = [[TransformationTestModel alloc] init];
            transformation = [[PROUniqueTransformation alloc] initWithInputValue:model outputValue:newModel];

            verifyTransformation = [^{
                setupBlock();

                id newValueBlock = [^(PROTransformation *transformation, id value, NSString *keyPath){
                    return NO;
                } copy];

                [blocks setObject:newValueBlock forKey:PROTransformationNewValueForKeyPathBlockKey];

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeFalsy();
                expect(newValueBlockInvoked).toBeFalsy();
            } copy];
        });

        it(@"should fall back to replacement if nested new value block fails", ^{
            PROUniqueTransformation *barTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:@"fizzbuzz"];
            PROKeyedTransformation *dictionaryTransformation = [[PROKeyedTransformation alloc] initWithTransformation:barTransformation forKey:@"bar"];

            PROTransformation *arrayTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:dictionaryTransformation];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:@"array"];

            verifyTransformation = [^{
                setupBlock();

                id blocksForIndexBlock = [^(PROTransformation *transformation, NSUInteger index, NSString *keyPath, NSDictionary *blocks){
                    id newValueBlock = [^(PROTransformation *transformation, id value, NSString *keyPath){
                        return NO;
                    } copy];

                    NSMutableDictionary *newBlocks = [blocks mutableCopy];
                    [newBlocks setObject:newValueBlock forKey:PROTransformationNewValueForKeyPathBlockKey];
                    return newBlocks;
                } copy];

                [blocks setObject:blocksForIndexBlock forKey:PROTransformationBlocksForIndexAtKeyPathBlockKey];

                id wrappedValueBlock = [^(PROTransformation *transformation, id value, NSString *keyPath){
                    expect(value).toBeKindOf([NSDictionary class]);
                    return [value allKeys];
                } copy];

                [blocks setObject:wrappedValueBlock forKey:PROTransformationWrappedValueForKeyPathBlockKey];

                TransformationTestModel *result = [transformation transform:model error:NULL];
                expect(result).not.toBeNil();

                expect([transformation applyBlocks:blocks transformationResult:result keyPath:nil]).toBeTruthy();

                // the replaced dictionary should have been "wrapped" as an NSArray
                NSArray *expectedArray = [NSArray arrayWithObject:[NSArray arrayWithObject:@"bar"]];
                expect(mutableArray).toEqual(expectedArray);
            } copy];
        });
    });

    after(^{
        it(@"should not be equal to a generic transformation", ^{
            PROTransformation *inequalTransformation = [[PROTransformation alloc] init];
            expect(inequalTransformation).not.toEqual(transformation);
        });

        it(@"should implement <NSCoding>", ^{
            expect(transformation).toConformTo(@protocol(NSCoding));

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:transformation];
            expect(encoded).not.toBeNil();

            PROTransformation *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            expect(decoded).toEqual(transformation);
        });

        it(@"should implement <NSCopying>", ^{
            expect(transformation).toConformTo(@protocol(NSCopying));

            PROTransformation *copied = [transformation copy];
            expect(copied).toEqual(transformation);
        });
    });

SpecEnd

@implementation TransformationTestModel
@synthesize array = m_array;
@end

@implementation TransformationInPlaceTestObject

#pragma mark Initialization

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_items = [[NSMutableArray alloc] init];
    return self;
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (NSUInteger)countOfItems {
    return m_items.count;
}

- (NSArray *)itemsAtIndexes:(NSIndexSet *)indexes {
    return [m_items objectsAtIndexes:indexes];
}

- (void)insertItems:(NSArray *)items atIndexes:(NSIndexSet *)indexes {
    [m_items insertObjects:items atIndexes:indexes];
}

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes {
    [m_items removeObjectsAtIndexes:indexes];
}

@end
