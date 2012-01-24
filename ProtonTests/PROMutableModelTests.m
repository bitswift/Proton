//
//  PROMutableModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

@interface MutabilityTestSubModel : PROModel
@property (nonatomic, assign, getter = isEnabled) BOOL enabled;

+ (id)enabledSubModel;
@end

@interface MutabilityTestModel : PROModel
@property (nonatomic, copy) NSArray *subModels;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double doubleValue;
@end

SpecBegin(PROMutableModel)

    __block MutabilityTestModel *immutableModel = nil;

    before(^{
        NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foobar", @"name",
            [NSNumber numberWithDouble:3.14], @"doubleValue",
            nil
        ];

        immutableModel = [[MutabilityTestModel alloc] initWithDictionary:initializationDictionary error:NULL];
    });

    describe(@"mutable model with model", ^{
        __block id model = nil;

        before(^{
            model = [[PROMutableModel alloc] initWithModel:immutableModel];
            expect(model).not.toBeNil();
        });

        it(@"should not have a model controller", ^{
            expect([model modelController]).toBeNil();
        });

        it(@"should consider model in equality", ^{
            PROMutableModel *equalModel = [[PROMutableModel alloc] initWithModel:immutableModel];
            expect(equalModel).toEqual(model);

            PROMutableModel *otherModel = [[PROMutableModel alloc] initWithModel:[MutabilityTestSubModel enabledSubModel]];
            expect(otherModel).not.toEqual(model);
        });

        it(@"should implement <NSCopying>", ^{
            expect(model).toConformTo(@protocol(NSCopying));

            MutabilityTestModel *copied = [model copy];
            expect(copied).toEqual(immutableModel);
            
            // this copy should not be a PROMutableModel
            expect(copied).toBeKindOf([PROModel class]);
        });

        it(@"should implement <NSMutableCopying>", ^{
            expect(model).toConformTo(@protocol(NSMutableCopying));

            PROMutableModel *copied = [model mutableCopy];
            expect(copied).toEqual(model);

            // this copy should be a PROMutableModel
            expect(copied).toBeKindOf([PROMutableModel class]);
        });

        it(@"should implement <NSCoding>", ^{
            expect(model).toConformTo(@protocol(NSCoding));

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:model];
            expect(encoded).not.toBeNil();

            PROMutableModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            expect(decoded).toEqual(model);

            // the decoded object should be a PROMutableModel
            expect(decoded).toBeKindOf([PROMutableModel class]);
        });

        it(@"should always succeed at saving", ^{
            __block NSError *error = nil;
            expect([model save:&error]).toBeTruthy();
            expect(error).toBeNil();
        });

        it(@"should forward unknown messages to the model", ^{
            PROKeyedTransformation *transformation = [model transformationForKey:@"name" value:@"fizzbuzz"];
            expect(transformation).not.toBeNil();
        });

        describe(@"getters", ^{
            it(@"should return an array", ^{
                expect([model subModels]).toEqual([NSArray array]);
            });

            it(@"should return a string", ^{
                expect([model name]).toEqual(@"foobar");
            });

            it(@"should return a double", ^{
                expect([model doubleValue]).toEqual(3.14);
            });
        });

        describe(@"setters", ^{
            it(@"should set an array", ^{
                expect(model).toRespondTo(@selector(setSubModels:));

                NSArray *subModels = [NSArray arrayWithObject:[[MutabilityTestSubModel alloc] init]];
                [model setSubModels:subModels];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should copy a mutable array", ^{
                MutabilityTestSubModel *subModel = [[MutabilityTestSubModel alloc] init];
                NSMutableArray *subModels = [NSMutableArray arrayWithObject:subModel];
                [model setSubModels:subModels];

                [subModels removeAllObjects];
                expect([model subModels]).toContain(subModel);
            });

            it(@"should set a string", ^{
                expect(model).toRespondTo(@selector(setName:));

                [model setName:@"foo"];
                expect([model name]).toEqual(@"foo");
            });

            it(@"should copy a mutable string", ^{
                NSMutableString *name = [@"fizz" mutableCopy];
                [model setName:name];

                [name appendString:@"buzz"];
                expect([model name]).toEqual(@"fizz");
            });

            it(@"should set a double", ^{
                expect(model).toRespondTo(@selector(setDoubleValue:));

                [model setDoubleValue:42.0];
                expect([model doubleValue]).toEqual(42.0);
            });
        });

        describe(@"key-value coding", ^{
            it(@"should return an array", ^{
                expect([model valueForKey:@"subModels"]).toEqual([model subModels]);
            });

            it(@"should return a string", ^{
                expect([model valueForKey:@"name"]).toEqual([model name]);
            });

            it(@"should return a double", ^{
                expect([model valueForKey:@"doubleValue"]).toEqual([model doubleValue]);
            });

            it(@"should set an array", ^{
                NSArray *subModels = [NSArray arrayWithObject:[MutabilityTestSubModel enabledSubModel]];
                [model setValue:subModels forKey:@"subModels"];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should mutate an array", ^{
                NSMutableArray *subModels = [[model subModels] mutableCopy];
                NSMutableArray *subModelsProxy = [model mutableArrayValueForKey:@"subModels"];
                expect(subModelsProxy).toEqual(subModels);

                [subModels insertObject:[MutabilityTestSubModel enabledSubModel] atIndex:0];
                [subModelsProxy insertObject:[MutabilityTestSubModel enabledSubModel] atIndex:0];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should set a string", ^{
                [model setValue:@"bazbuzz" forKey:@"name"];
                expect([model name]).toEqual(@"bazbuzz");
            });

            it(@"should set a double", ^{
                [model setValue:[NSNumber numberWithDouble:5.5] forKey:@"doubleValue"];
                expect([model doubleValue]).toEqual(5.5);
            });
        });

        describe(@"key-value observing", ^{
            __block PROKeyValueObserver *observer = nil;
            __block BOOL observerInvoked;

            before(^{
                observerInvoked = NO;
            });

            after(^{
                expect(observerInvoked).toBeTruthy();

                observer = nil;
            });

            it(@"should generate KVO notification for setting an array", ^{
                NSArray *subModels = [NSArray arrayWithObject:[MutabilityTestSubModel enabledSubModel]];

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"subModels"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([changes objectForKey:NSKeyValueChangeNewKey]).toEqual(subModels);
                    }
                ];

                [model setSubModels:subModels];
            });

            it(@"should generate KVO notification for mutating an array", ^{
                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"subModels"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([changes objectForKey:NSKeyValueChangeNewKey]).toEqual([MutabilityTestSubModel enabledSubModel]);
                    }
                ];

                [[model mutableArrayValueForKey:@"subModels"] addObject:[MutabilityTestSubModel enabledSubModel]];
            });

            it(@"should generate KVO notification for setting a string", ^{
                NSString *newName = @"fizzbaz";

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"name"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([changes objectForKey:NSKeyValueChangeNewKey]).toEqual(newName);
                    }
                ];

                [model setName:newName];
            });

            it(@"should generate KVO notification for setting a primitive", ^{
                double newValue = -4.5;

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"name"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([[changes objectForKey:NSKeyValueChangeNewKey] doubleValue]).toEqual(newValue);
                    }
                ];

                [model setDoubleValue:newValue];
            });
        });
    });

    describe(@"mutable model with model controller", ^{
        __block PROModelController *modelController = nil;
        __block id model = nil;

        before(^{
            modelController = [[PROModelController alloc] initWithModel:immutableModel];

            model = [[PROMutableModel alloc] initWithModelController:modelController];
            expect(model).not.toBeNil();
        });

        it(@"should have a model controller", ^{
            expect([model modelController]).toEqual(modelController);
        });

        it(@"should copy model controller", ^{
            PROMutableModel *copied = [model mutableCopy];
            expect(copied.modelController).toEqual(modelController);
        });

        it(@"should encode model controller", ^{
            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:model];
            expect(encoded).not.toBeNil();

            PROMutableModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];

            // model controllers do not implement equality, so check the models
            // instead
            expect(decoded.modelController.model).toEqual(modelController.model);
        });

        it(@"should save to model controller", ^{
            [model setName:@"fizzbuzz"];
            
            __block NSError *error = nil;
            expect([model save:&error]).toBeTruthy();
            expect(error).toBeNil();

            expect([modelController.model name]).toEqual(@"fizzbuzz");
        });

        it(@"should fail to save if model controller conflicts", ^{
            [model setName:@"fizzbuzz"];

            PROTransformation *nameTransformation = [immutableModel transformationForKey:@"name" value:@"fuzz"];
            expect([modelController performTransformation:nameTransformation error:NULL]).toBeTruthy();
            
            __block NSError *error = nil;
            expect([model save:&error]).toBeFalsy();

            expect(error.domain).toEqual([PROTransformation errorDomain]);
            expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
            expect([error.userInfo objectForKey:PROTransformationFailingTransformationPathErrorKey]).toEqual(@"name");
        });

        it(@"should not change when the model controller changes", ^{
            PROTransformation *nameTransformation = [immutableModel transformationForKey:@"name" value:@"fuzz"];
            expect([modelController performTransformation:nameTransformation error:NULL]).toBeTruthy();

            // the mutable model should still have the old value
            expect([model name]).toEqual(immutableModel.name);
        });

        it(@"should save multiple changes to model controller", ^{
            [model setName:@"fizzbuzz"];

            NSArray *newSubModels = [NSArray arrayWithObject:[MutabilityTestSubModel enabledSubModel]];
            [model setSubModels:newSubModels];
            
            __block NSError *error = nil;
            expect([model save:&error]).toBeTruthy();
            expect(error).toBeNil();

            expect([modelController.model name]).toEqual(@"fizzbuzz");
            expect([modelController.model subModels]).toEqual(newSubModels);
        });
    });

SpecEnd

@implementation MutabilityTestSubModel
@synthesize enabled = m_enabled;

+ (id)enabledSubModel; {
    NSDictionary *subModelDictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
    return [[self alloc] initWithDictionary:subModelDictionary error:NULL];
}
@end

@implementation MutabilityTestModel
@synthesize subModels = m_subModels;
@synthesize name = m_name;
@synthesize doubleValue = m_doubleValue;
@end
