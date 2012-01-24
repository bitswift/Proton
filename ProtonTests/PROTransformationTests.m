//
//  PROTransformationTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

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
