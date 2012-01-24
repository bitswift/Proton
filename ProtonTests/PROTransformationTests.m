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

SpecBegin(PROTransformation)
    __block id transformation = nil;

    after(^{
        transformation = nil;
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
            __block NSError *error = nil;
            expect([transformation transform:uniqueInputValue error:&error]).toEqual(uniqueInputValue);
            expect(error).toBeNil();
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

            it(@"transforms the input value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:uniqueInputValue error:&error]).toEqual(uniqueOutputValue);
                expect(error).toBeNil();
            });

            it(@"doesn't transform another value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:uniqueOutputValue error:&error]).toBeNil();

                expect(error.domain).toEqual([PROTransformation errorDomain]);
                expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
                expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                PROUniqueTransformation *reverseTransformation = (id)[transformation reverseTransformation];
                expect(reverseTransformation.inputValue).toEqual(uniqueOutputValue);
                expect(reverseTransformation.outputValue).toEqual(uniqueInputValue);

                __block NSError *error = nil;
                expect([reverseTransformation transform:uniqueOutputValue error:&error]).toEqual(uniqueInputValue);
                expect(error).toBeNil();
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

            // values should just pass through
            __block NSError *error = nil;
            expect([transformation transform:startArray error:&error]).toEqual(startArray);
            expect(error).toBeNil();
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

            it(@"transforms the input value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(endArray);
                expect(error).toBeNil();
            });

            it(@"doesn't transform out of bounds indexes", ^{
                __block NSError *error = nil;
                expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                expect(error.domain).toEqual([PROTransformation errorDomain]);
                expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                PROTransformation *reverseTransformation = [transformation reverseTransformation];

                __block NSError *error = nil;
                expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
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

            // values should just pass through
            __block NSError *error = nil;
            expect([transformation transform:startDictionary error:&error]).toEqual(startDictionary);
            expect(error).toBeNil();
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

            it(@"transforms the input value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:startDictionary error:&error]).toEqual(endDictionary);
                expect(error).toBeNil();
            });

            it(@"treats missing values as NSNull", ^{
                NSMutableDictionary *modifiedStartDictionary = [startDictionary mutableCopy];

                // remove the key associated with NSNull
                [modifiedStartDictionary removeObjectForKey:@"nil"];

                __block NSError *error = nil;
                expect([transformation transform:modifiedStartDictionary error:&error]).toEqual(endDictionary);
                expect(error).toBeNil();
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                PROTransformation *reverseTransformation = [transformation reverseTransformation];

                __block NSError *error = nil;
                expect([reverseTransformation transform:endDictionary error:&error]).toEqual(startDictionary);
                expect(error).toBeNil();
            });
        });

        it(@"should transform custom class", ^{
            NSArray *endArray = [NSArray arrayWithObject:@"foobar"];
            PROUniqueTransformation *arrayTransformation = [[PROUniqueTransformation alloc] initWithInputValue:[NSArray array] outputValue:endArray];

            TransformationTestModel *model = [[TransformationTestModel alloc] init];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:arrayTransformation forKey:PROKeyForObject(model, array)];

            TransformationTestModel *expectedModel = [[TransformationTestModel alloc] init];
            expectedModel.array = endArray;

            __block NSError *error = nil;
            expect([transformation transform:model error:&error]).toEqual(expectedModel);
            expect(error).toBeNil();
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

            // values should just pass through
            __block NSError *error = nil;
            expect([transformation transform:multipleStartValue error:&error]).toEqual(multipleStartValue);
            expect(error).toBeNil();
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

            it(@"transforms the input value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:multipleStartValue error:&error]).toEqual(multipleEndValue);
                expect(error).toBeNil();
            });

            it(@"doesn't transform another value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:multipleMiddleValue error:&error]).toBeNil();

                expect(error.domain).toEqual([PROTransformation errorDomain]);
                expect(error.code).toEqual(PROTransformationErrorMismatchedInput);

                NSArray *failingTransformations = [NSArray arrayWithObjects:transformation, [transformations objectAtIndex:0], nil];
                expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual(failingTransformations);
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                PROTransformation *reverseTransformation = [transformation reverseTransformation];

                __block NSError *error = nil;
                expect([reverseTransformation transform:multipleEndValue error:&error]).toEqual(multipleStartValue);
                expect(error).toBeNil();
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

            // values should just pass through
            __block NSError *error = nil;
            expect([transformation transform:startArray error:&error]).toEqual(startArray);
            expect(error).toBeNil();
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

            it(@"transforms the input value to the output value", ^{
                __block NSError *error = nil;
                expect([transformation transform:startArray error:&error]).toEqual(endArray);
                expect(error).toBeNil();
            });

            it(@"doesn't transform out of bounds indexes", ^{
                __block NSError *error = nil;
                expect([transformation transform:[NSArray array] error:&error]).toBeNil();

                expect(error.domain).toEqual([PROTransformation errorDomain]);
                expect(error.code).toEqual(PROTransformationErrorIndexOutOfBounds);
                expect([error.userInfo objectForKey:PROTransformationFailingTransformationsErrorKey]).toEqual([NSArray arrayWithObject:transformation]);
            });

            it(@"should return a reverse transformation which does the opposite", ^{
                PROTransformation *reverseTransformation = [transformation reverseTransformation];

                __block NSError *error = nil;
                expect([reverseTransformation transform:endArray error:&error]).toEqual(startArray);
                expect(error).toBeNil();
            });
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
