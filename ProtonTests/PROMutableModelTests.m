//
//  PROMutableModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    #import <ApplicationServices/ApplicationServices.h>
#else
    #import <UIKit/UIKit.h>

    // really annoying
    #define valueWithRect valueWithCGRect
    #define rectValue CGRectValue
#endif

@interface MutabilityTestSubModel : PROModel
@property (nonatomic, assign, getter = isEnabled) BOOL enabled;

+ (id)enabledSubModel;
@end

@interface MutabilityTestModel : PROModel
@property (nonatomic, copy) NSArray *subModels;
@property (nonatomic, copy) NSSet *strings;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) long longValue;
@property (nonatomic, assign) CGRect frame;
@end

SpecBegin(PROMutableModel)

    __block MutabilityTestModel *immutableModel = nil;

    CGRect initialFrame = CGRectMake(0, 0, 20, 20);

    before(^{
        NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foobar", @"name",
            [NSNumber numberWithLong:42], @"longValue",
            [NSValue valueWithRect:initialFrame], @"frame",
            [NSArray arrayWithObject:[[MutabilityTestSubModel alloc] init]], @"subModels",
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
                expect([model subModels]).toEqual([immutableModel subModels]);
            });

            it(@"should return a string", ^{
                expect([model name]).toEqual([immutableModel name]);
            });

            it(@"should return a primitive", ^{
                expect([model longValue]).toEqual([immutableModel longValue]);
            });

            it(@"should return a structure", ^{
                expect([model frame]).toEqual([immutableModel frame]);
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

            it(@"should set a primitive", ^{
                expect(model).toRespondTo(@selector(setLongValue:));

                [model setLongValue:-20];
                expect([model longValue]).toEqual(-20);
            });

            it(@"should set a structure", ^{
                expect(model).toRespondTo(@selector(setFrame:));

                [model setFrame:CGRectInfinite];
                expect([model frame]).toEqual(CGRectInfinite);
            });
        });

        describe(@"key-value coding", ^{
            it(@"should return an array", ^{
                expect([model valueForKey:@"subModels"]).toEqual([model subModels]);
            });

            it(@"should return a string", ^{
                expect([model valueForKey:@"name"]).toEqual([model name]);
            });

            it(@"should return a primitive", ^{
                expect([[model valueForKey:@"longValue"] longValue]).toEqual([model longValue]);
            });

            it(@"should return a structure", ^{
                expect([[model valueForKey:@"frame"] rectValue]).toEqual([model frame]);
            });

            it(@"should set an array", ^{
                NSArray *subModels = [NSArray arrayWithObject:[MutabilityTestSubModel enabledSubModel]];
                [model setValue:subModels forKey:@"subModels"];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should insert into an array", ^{
                NSMutableArray *subModels = [[model subModels] mutableCopy];
                NSMutableArray *subModelsProxy = [model mutableArrayValueForKey:@"subModels"];
                expect(subModelsProxy).toEqual(subModels);

                [subModels insertObject:[MutabilityTestSubModel enabledSubModel] atIndex:0];
                [subModelsProxy insertObject:[MutabilityTestSubModel enabledSubModel] atIndex:0];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should remove from an array", ^{
                NSMutableArray *subModelsProxy = [model mutableArrayValueForKey:@"subModels"];
                NSMutableArray *subModels = [[model subModels] mutableCopy];
                expect(subModelsProxy).toEqual(subModels);

                [subModels removeObjectAtIndex:0];
                [subModelsProxy removeObjectAtIndex:0];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should replace in an array", ^{
                NSMutableArray *subModelsProxy = [model mutableArrayValueForKey:@"subModels"];
                NSMutableArray *subModels = [[model subModels] mutableCopy];
                expect(subModelsProxy).toEqual(subModels);

                [subModels replaceObjectAtIndex:0 withObject:[MutabilityTestSubModel enabledSubModel]];
                [subModelsProxy replaceObjectAtIndex:0 withObject:[MutabilityTestSubModel enabledSubModel]];

                expect([model subModels]).toEqual(subModels);
            });

            it(@"should set a string", ^{
                [model setValue:@"bazbuzz" forKey:@"name"];
                expect([model name]).toEqual(@"bazbuzz");
            });

            it(@"should set a primitive", ^{
                [model setValue:[NSNumber numberWithLong:8] forKey:@"longValue"];
                expect([model longValue]).toEqual(8);
            });

            it(@"should set a structure", ^{
                CGRect newRect = CGRectMake(0, 20, 50, 80);

                [model setValue:[NSValue valueWithRect:newRect] forKey:@"frame"];
                expect([model frame]).toEqual(newRect);
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

            describe(@"array mutation", ^{
                __block NSKeyValueChange change;
                __block NSIndexSet *indexes;

                before(^{
                    indexes = nil;

                    observer = [[PROKeyValueObserver alloc]
                        initWithTarget:model
                        keyPath:@"subModels"
                        options:NSKeyValueObservingOptionNew
                        block:^(NSDictionary *changes){
                            observerInvoked = YES;

                            expect([[changes objectForKey:NSKeyValueChangeKindKey] integerValue]).toEqual(change);

                            if (indexes)
                                expect([changes objectForKey:NSKeyValueChangeIndexesKey]).toEqual(indexes);
                        }
                    ];
                });

                it(@"should generate notification for setting", ^{
                    change = NSKeyValueChangeSetting;

                    NSArray *subModels = [NSArray arrayWithObject:[MutabilityTestSubModel enabledSubModel]];
                    [model setSubModels:subModels];
                });

                it(@"should generate notification for inserting", ^{
                    indexes = [NSIndexSet indexSetWithIndex:[[model subModels] count]];
                    change = NSKeyValueChangeInsertion;

                    [[model mutableArrayValueForKey:@"subModels"] addObject:[MutabilityTestSubModel enabledSubModel]];
                });

                it(@"should generate notification for removing", ^{
                    indexes = [NSIndexSet indexSetWithIndex:0];
                    change = NSKeyValueChangeRemoval;

                    [[model mutableArrayValueForKey:@"subModels"] removeObjectAtIndex:0];
                });

                it(@"should generate notification for replacement", ^{
                    indexes = [NSIndexSet indexSetWithIndex:0];
                    change = NSKeyValueChangeReplacement;

                    [[model mutableArrayValueForKey:@"subModels"] replaceObjectAtIndex:0 withObject:[MutabilityTestSubModel enabledSubModel]];
                });
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
                long newValue = -55;

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"longValue"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([[changes objectForKey:NSKeyValueChangeNewKey] longValue]).toEqual(newValue);
                    }
                ];

                [model setLongValue:newValue];
            });

            it(@"should generate KVO notification for setting a structure", ^{
                CGRect newRect = CGRectMake(0, 20, 50, 80);

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"frame"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        expect([[changes objectForKey:NSKeyValueChangeNewKey] rectValue]).toEqual(newRect);
                    }
                ];

                [model setFrame:newRect];
            });
        });

        describe(@"thread safety", ^{
            before(^{
                [[model mutableArrayValueForKey:@"subModels"] removeAllObjects];
            });

            it(@"should serialize sub-model insertions", ^{
                NSArray *newSubModels = [NSArray arrayWithObjects:
                    [MutabilityTestSubModel enabledSubModel],
                    [MutabilityTestSubModel enabledSubModel],
                    [[MutabilityTestSubModel alloc] init],
                    [MutabilityTestSubModel enabledSubModel],
                    [[MutabilityTestSubModel alloc] init],
                    [[MutabilityTestSubModel alloc] init],
                    [[MutabilityTestSubModel alloc] init],
                    [MutabilityTestSubModel enabledSubModel],
                    [[MutabilityTestSubModel alloc] init],
                    [MutabilityTestSubModel enabledSubModel],
                    [MutabilityTestSubModel enabledSubModel],
                    [[MutabilityTestSubModel alloc] init],
                    [[MutabilityTestSubModel alloc] init],
                    nil
                ];

                NSMutableArray *mutableSubModels = [model mutableArrayValueForKey:@"subModels"];

                dispatch_apply(newSubModels.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
                    MutabilityTestSubModel *subModel = [newSubModels objectAtIndex:i];
                    [mutableSubModels addObject:subModel];

                    expect([model subModels]).toContain(subModel);
                    expect(mutableSubModels).toContain(subModel);
                });

                NSArray *subModels = [model subModels];
                expect(subModels.count).toEqual(newSubModels.count);
                expect(mutableSubModels.count).toEqual(newSubModels.count);

                for (id subModel in newSubModels) {
                    expect(subModels).toContain(subModel);
                    expect(mutableSubModels).toContain(subModel);
                }
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
            expect(decoded.modelController).toEqual(modelController);
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

        describe(@"rebasing", ^{
            __block BOOL rebaseSucceeded;
            __block NSError *rebaseError;

            __block id successObserver;
            __block id failureObserver;

            before(^{
                rebaseSucceeded = NO;
                rebaseError = nil;

                successObserver = [[NSNotificationCenter defaultCenter]
                    addObserverForName:PROMutableModelDidRebaseFromModelControllerNotification
                    object:model
                    queue:nil
                    usingBlock:^(NSNotification *notification){
                        expect(rebaseError).toBeNil();
                        expect(notification.object).toEqual(model);

                        rebaseSucceeded = YES;
                    }
                ];

                failureObserver = [[NSNotificationCenter defaultCenter]
                    addObserverForName:PROMutableModelRebaseFromModelControllerFailedNotification
                    object:model
                    queue:nil
                    usingBlock:^(NSNotification *notification){
                        expect(rebaseSucceeded).toBeFalsy();
                        expect(notification.object).toEqual(model);

                        rebaseError = [notification.userInfo objectForKey:PROMutableModelRebaseErrorKey];
                        expect(rebaseError).not.toBeNil();
                    }
                ];
            });

            after(^{
                [[NSNotificationCenter defaultCenter] removeObserver:successObserver];
                successObserver = nil;

                [[NSNotificationCenter defaultCenter] removeObserver:failureObserver];
                failureObserver = nil;
            });

            it(@"should rebase from model controller without any changes", ^{
                NSString *newName = @"this is a new name";
                PROTransformation *transformation = [modelController.model transformationForKey:@"name" value:newName];
                expect([modelController performTransformation:transformation error:NULL]).toBeTruthy();

                expect(rebaseSucceeded).toBeTruthy();
                expect([model valueForKey:@"name"]).toEqual(newName);
                expect([[modelController model] name]).toEqual(newName);
            });

            it(@"should rebase from model controller with non-conflicting changes", ^{
                NSSet *strings = [NSSet setWithObject:@"this is a new string set"];
                [model setValue:strings forKey:@"strings"];

                NSString *newName = @"this is a new name";
                PROTransformation *transformation = [modelController.model transformationForKey:@"name" value:newName];
                expect([modelController performTransformation:transformation error:NULL]).toBeTruthy();

                expect(rebaseSucceeded).toBeTruthy();
                expect([model valueForKey:@"name"]).toEqual(newName);
                expect([model valueForKey:@"strings"]).toEqual(strings);

                expect([[modelController model] name]).toEqual(newName);
                expect([[modelController model] strings]).toEqual([NSSet set]);
            });

            it(@"should not rebase from model controller with conflicting changes", ^{
                NSString *conflictingName = @"this is a conflicting name";
                [model setName:@"this is a conflicting name"];

                NSString *newName = @"this is a new name";
                PROTransformation *transformation = [modelController.model transformationForKey:@"name" value:newName];
                expect([modelController performTransformation:transformation error:NULL]).toBeTruthy();

                expect(rebaseSucceeded).toBeFalsy();
                expect(rebaseError.domain).toEqual([PROTransformation errorDomain]);
                expect(rebaseError.code).toEqual(PROTransformationErrorMismatchedInput);

                expect([model valueForKey:@"name"]).toEqual(conflictingName);
                expect([[modelController model] name]).toEqual(newName);
            });
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
@synthesize longValue = m_longValue;
@synthesize frame = m_frame;
@synthesize strings = m_strings;
@end
