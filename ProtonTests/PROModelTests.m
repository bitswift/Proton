//
//  PROModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/EXTScope.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROModel.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueTransformation.h>

@interface TestModel : PROModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, getter = isEnabled) BOOL enabled;
@end

@interface CollectionTestModel : PROModel
@property (nonatomic, copy) NSArray *array;
@property (nonatomic, copy) NSDictionary *dictionary;
@property (nonatomic, copy) NSOrderedSet *orderedSet;
@property (nonatomic, copy) NSSet *set;
@end

SpecBegin(PROModel)

    describe(@"base class", ^{
        it(@"has no propertyKeys", ^{
            expect([PROModel propertyKeys]).toBeNil();
        });

        it(@"has no propertyClassesByKey", ^{
            expect([[PROModel propertyClassesByKey] count]).toEqual(0);
        });

        it(@"has no defaultValuesForKeys", ^{
            expect([[PROModel defaultValuesForKeys] count]).toEqual(0);
        });
    });

    describe(@"TestModel subclass", ^{
        it(@"has propertyKeys", ^{
            expect([TestModel propertyKeys]).toContain(@"name");
            expect([TestModel propertyKeys]).toContain(@"date");
            expect([TestModel propertyKeys]).toContain(@"enabled");

            expect([TestModel propertyKeys]).not.toContain(@"array");
        });

        it(@"has propertyClassesByKey", ^{
            expect([[TestModel propertyClassesByKey] objectForKey:@"name"]).toEqual([NSString class]);
            expect([[TestModel propertyClassesByKey] objectForKey:@"date"]).toEqual([NSDate class]);
            expect([[TestModel propertyClassesByKey] objectForKey:@"enabled"]).toBeNil();
        });

        it(@"has no defaultValuesForKeys", ^{
            expect([[TestModel defaultValuesForKeys] count]).toEqual(0);
        });

        it(@"initializes", ^{
            TestModel *model = [[TestModel alloc] init];
            expect(model).not.toBeNil();

            expect(model.name).toBeNil();
            expect(model.date).toBeNil();
            expect(model.enabled).toBeFalsy();

            expect([model.dictionaryValue objectForKey:@"name"]).toEqual([NSNull null]);
            expect([model.dictionaryValue objectForKey:@"date"]).toEqual([NSNull null]);
            expect([[model.dictionaryValue objectForKey:@"enabled"] boolValue]).toBeFalsy();
        });

        describe(@"initialized with dictionary", ^{
            NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];

            __block TestModel *model = nil;

            before(^{
                NSError *error = nil;
                model = [[TestModel alloc] initWithDictionary:initializationDictionary error:&error];

                expect(model).not.toBeNil();
                expect(error).toBeNil();

                expect([model valueForKey:@"name"]).toEqual(@"foobar");
            });

            it(@"has correct dictionary value", ^{
                NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"foobar", @"name",
                    [NSNull null], @"date",
                    [NSNumber numberWithBool:NO], @"enabled",
                    nil
                ];

                expect(model.dictionaryValue).toEqual(expectedDictionaryValue);
            });

            it(@"is equal to same model data", ^{
                TestModel *otherModel = [[TestModel alloc] initWithDictionary:initializationDictionary error:NULL];
                expect(model).toEqual(otherModel);
            });

            it(@"is not equal to a different model", ^{
                TestModel *otherModel = [[TestModel alloc] init];
                expect(model).not.toEqual(otherModel);
            });

            it(@"implements <NSCoding>", ^{
                expect(model).toConformTo(@protocol(NSCoding));

                NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:model];
                expect(encoded).not.toBeNil();

                PROModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
                expect(decoded).toEqual(model);
            });

            it(@"implements <NSCopying>", ^{
                expect(model).toConformTo(@protocol(NSCopying));

                PROModel *copied = [model copy];
                expect(model).toEqual(copied);
            });
            
            it(@"has transformation for valid key", ^{
                PROKeyedTransformation *transformation = [model transformationForKey:@"name" value:@"fizzbuzz"];
                expect(transformation).toBeKindOf([PROKeyedTransformation class]);
                
                // should be just the one transformation we specified
                expect(transformation.valueTransformations.count).toEqual(1);

                // the only transformation should be a unique transformation from 'foobar'
                // to 'fizzbuzz'
                PROUniqueTransformation *uniqueTransformation = [transformation.valueTransformations objectForKey:@"name"];
                expect(uniqueTransformation).toBeKindOf([PROUniqueTransformation class]);

                expect(uniqueTransformation.inputValue).toEqual(model.name);
                expect(uniqueTransformation.outputValue).toEqual(@"fizzbuzz");
            });

            it(@"doesn't have transformation to key already transformed", ^{
                PROKeyedTransformation *transformation = [model transformationForKey:@"name" value:model.name];
                expect(transformation).toBeNil();
            });

            describe(@"has transformation for keys with dictionary", ^{
                NSDate *now = [[NSDate alloc] init];

                __block PROKeyedTransformation *transformation;
                
                before(^{
                    NSDictionary *changes = [NSDictionary dictionaryWithObjectsAndKeys:
                        @"fizzbuzz", @"name",
                        now, @"date",
                        nil
                    ];

                    transformation = [model transformationForKeysWithDictionary:changes];
                    expect(transformation).toBeKindOf([PROKeyedTransformation class]);
                    
                    // should be just the two transformations we specified
                    expect(transformation.valueTransformations.count).toEqual(2);
                });

                it(@"including a unique transformation from 'foobar' to 'fizzbuzz'", ^{
                    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:model.name outputValue:@"fizzbuzz"];
                    expect([transformation.valueTransformations objectForKey:@"name"]).toEqual(uniqueTransformation);
                });

                it(@"including a unique transformation from the default date to now", ^{
                    PROUniqueTransformation *uniqueTransformation = [[PROUniqueTransformation alloc] initWithInputValue:model.date outputValue:now];
                    expect([transformation.valueTransformations objectForKey:@"date"]).toEqual(uniqueTransformation);
                });
            });

            it(@"doesn't have transformation to keys already transformed", ^{
                NSDictionary *changes = [NSDictionary dictionaryWithObjectsAndKeys:
                    model.name, @"name",
                    model.date, @"date",
                    nil
                ];

                PROKeyedTransformation *transformation = [model transformationForKeysWithDictionary:changes];
                expect(transformation).toBeNil();
            });
        });

        it(@"fails to initialize with invalid value", ^{
            // this name is too short to pass the validation method
            NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObject:@"blah" forKey:@"name"];

            NSError *error = nil;
            TestModel *model = [[TestModel alloc] initWithDictionary:initializationDictionary error:&error];
            expect(model).toBeNil();

            expect(error.domain).toEqual([PROModel errorDomain]);
            expect(error.code).toEqual(PROModelErrorValidationFailed);
            expect([error.userInfo objectForKey:PROModelPropertyKeyErrorKey]).toEqual(@"name");
        });

        it(@"fails to initialize with invalid key", ^{
            NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObject:@"blah" forKey:@"invalidKey"];

            NSError *error = nil;
            TestModel *model = [[TestModel alloc] initWithDictionary:initializationDictionary error:&error];
            expect(model).toBeNil();

            expect(error.domain).toEqual([PROModel errorDomain]);
            expect(error.code).toEqual(PROModelErrorUndefinedKey);
            expect([error.userInfo objectForKey:PROModelPropertyKeyErrorKey]).toEqual(@"invalidKey");
        });
    });

    describe(@"CollectionTestModel subclass", ^{
        it(@"has propertyKeys", ^{
            expect([CollectionTestModel propertyKeys]).toContain(@"array");
            expect([CollectionTestModel propertyKeys]).toContain(@"dictionary");
            expect([CollectionTestModel propertyKeys]).toContain(@"orderedSet");
            expect([CollectionTestModel propertyKeys]).toContain(@"set");

            expect([CollectionTestModel propertyKeys]).not.toContain(@"name");
        });

        it(@"has propertyClassesByKey", ^{
            expect([[CollectionTestModel propertyClassesByKey] objectForKey:@"array"]).toEqual([NSArray class]);
            expect([[CollectionTestModel propertyClassesByKey] objectForKey:@"dictionary"]).toEqual([NSDictionary class]);
            expect([[CollectionTestModel propertyClassesByKey] objectForKey:@"orderedSet"]).toEqual([NSOrderedSet class]);
            expect([[CollectionTestModel propertyClassesByKey] objectForKey:@"set"]).toEqual([NSSet class]);
        });

        it(@"has defaultValuesForKeys", ^{
            expect([[CollectionTestModel defaultValuesForKeys] objectForKey:@"array"]).toEqual([NSArray array]);
            expect([[CollectionTestModel defaultValuesForKeys] objectForKey:@"dictionary"]).toEqual([NSDictionary dictionary]);
            expect([[CollectionTestModel defaultValuesForKeys] objectForKey:@"orderedSet"]).toEqual([NSOrderedSet orderedSet]);
            expect([[CollectionTestModel defaultValuesForKeys] objectForKey:@"set"]).toEqual([NSSet set]);
        });

        it(@"initializes with default values", ^{
            CollectionTestModel *model = [[CollectionTestModel alloc] init];
            expect(model).not.toBeNil();
            expect(model.dictionaryValue).toEqual([CollectionTestModel defaultValuesForKeys]);

            NSArray *keys = [[CollectionTestModel defaultValuesForKeys] allKeys];
            expect([model dictionaryWithValuesForKeys:keys]).toEqual([CollectionTestModel defaultValuesForKeys]);
        });
    });

SpecEnd

@implementation TestModel
@synthesize name = m_name;
@synthesize date = m_date;
@synthesize enabled = m_enabled;

- (BOOL)validateName:(NSString **)name error:(NSError **)error {
    // consider the name valid if its length is at least 5 characters (or if it
    // wasn't provided at all)
    return (*name == nil) || [*name length] >= 5;
}

@end

@implementation CollectionTestModel
@synthesize array = m_array;
@synthesize dictionary = m_dictionary;
@synthesize orderedSet = m_orderedSet;
@synthesize set = m_set;
@end
