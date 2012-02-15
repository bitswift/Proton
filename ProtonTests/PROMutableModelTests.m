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

@interface TestSubModel : PROModel
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, getter = isEnabled, readonly) BOOL enabled;

+ (id)enabledSubModel;
- (id)initWithName:(NSString *)name;
@end

@interface TestSuperModel : PROModel
@property (nonatomic, copy, readonly) NSArray *subModels;
@property (nonatomic, copy, readonly) NSArray *subArray;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) long longValue;
@property (nonatomic, assign, readonly) CGRect frame;

- (id)initWithSubModel:(TestSubModel *)subModel;
@end

@mutable(TestMutableSubModel, TestSubModel)
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, getter = isEnabled, readwrite) BOOL enabled;
@end

@mutable(TestMutableSuperModel, TestSuperModel)
@property (nonatomic, copy, readwrite) NSArray *subModels;
@property (nonatomic, copy, readwrite) NSArray *subArray;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, assign, readwrite) long longValue;
@property (nonatomic, assign, readwrite) CGRect frame;
@end

SpecBegin(PROMutableModel)

    __block TestSuperModel *immutableModel = nil;

    CGRect initialFrame = CGRectMake(0, 0, 20, 20);

    before(^{
        NSDictionary *initializationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foobar", @"name",
            [NSNumber numberWithLong:42], @"longValue",
            [NSValue valueWithRect:initialFrame], @"frame",
            [NSArray arrayWithObject:[[TestSubModel alloc] init]], @"subModels",
            nil
        ];

        immutableModel = [[TestSuperModel alloc] initWithDictionary:initializationDictionary error:NULL];
    });

    __block TestMutableSuperModel *model = nil;

    before(^{
        model = (id)[[PROMutableModel alloc] initWithModel:immutableModel];
        expect(model).not.toBeNil();
    });

    it(@"should consider model in equality", ^{
        PROMutableModel *equalModel = [[PROMutableModel alloc] initWithModel:immutableModel];
        expect(equalModel).toEqual(model);

        PROMutableModel *otherModel = [[PROMutableModel alloc] initWithModel:[TestSubModel enabledSubModel]];
        expect(otherModel).not.toEqual(model);
    });

    it(@"should implement <NSCopying>", ^{
        expect(model).toConformTo(@protocol(NSCopying));

        TestSuperModel *copied = [model copy];
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
        expect(model).toSupportArchiving();
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

        it(@"should return an array with sub-mutable models", ^{
            expect([model subModels]).toEqual([immutableModel subModels]);

            [model.subModels enumerateObjectsUsingBlock:^(id subModel, NSUInteger idx, BOOL *stop) {
                expect(subModel).toBeKindOf([PROMutableModel class]);
                expect(subModel).toEqual([immutableModel.subModels objectAtIndex:idx]);
            }];
        });
    });

    describe(@"setters", ^{
        it(@"should set an array", ^{
            expect(model).toRespondTo(@selector(setSubModels:));

            NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
            model.subModels = subModels;

            expect([model subModels]).toEqual(subModels);
        });

        it(@"should copy a mutable array", ^{
            TestSubModel *subModel = [[TestSubModel alloc] init];
            NSMutableArray *subModels = [NSMutableArray arrayWithObject:subModel];
            model.subModels = subModels;

            [subModels removeAllObjects];
            expect([model subModels]).toContain(subModel);
        });

        it(@"should set a string", ^{
            expect(model).toRespondTo(@selector(setName:));

            model.name = @"foo";
            expect([model name]).toEqual(@"foo");
        });

        it(@"should copy a mutable string", ^{
            NSMutableString *name = [@"fizz" mutableCopy];
            model.name = name;

            [name appendString:@"buzz"];
            expect([model name]).toEqual(@"fizz");
        });

        it(@"should set a primitive", ^{
            expect(model).toRespondTo(@selector(setLongValue:));

            model.longValue = -20;
            expect([model longValue]).toEqual(-20);
        });

        it(@"should set a structure", ^{
            expect(model).toRespondTo(@selector(setFrame:));

            model.frame = CGRectInfinite;
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
            NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
            [model setValue:subModels forKey:@"subModels"];

            expect([model subModels]).toEqual(subModels);
        });

        it(@"should insert into an array", ^{
            NSMutableArray *subModels = [[model subModels] mutableCopy];
            NSMutableArray *subModelsProxy = [model mutableArrayValueForKey:@"subModels"];
            expect(subModelsProxy).toEqual(subModels);

            [subModels insertObject:[TestSubModel enabledSubModel] atIndex:0];
            [subModelsProxy insertObject:[TestSubModel enabledSubModel] atIndex:0];

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

            [subModels replaceObjectAtIndex:0 withObject:[TestSubModel enabledSubModel]];
            [subModelsProxy replaceObjectAtIndex:0 withObject:[TestSubModel enabledSubModel]];

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

    describe(@"successful transformations", ^{
        __block PROTransformation *transformation;

        before(^{
            transformation = nil;
        });

        after(^{
            TestSuperModel *originalModel = model.copy;
            TestSuperModel *expectedModel = [transformation transform:originalModel error:NULL];
            expect(expectedModel).not.toBeNil();

            __block NSError *error = nil;
            expect([model applyTransformation:transformation error:&error]).toBeTruthy();
            expect(error).toBeNil();

            expect(model).toEqual(expectedModel);
            expect(model.subModels).toEqual(expectedModel.subModels);
        });

        it(@"should perform a unique transformation", ^{
            TestSuperModel *newModel = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];

            transformation = [[PROUniqueTransformation alloc] initWithInputValue:immutableModel outputValue:newModel];
        });
        
        it(@"should perform a keyed transformation", ^{
            NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];

            transformation = [immutableModel transformationForKey:PROKeyForObject(immutableModel, subModels) value:subModels];
        });

        it(@"should perform an insertion transformation", ^{
            TestSubModel *subModel = [[TestSubModel alloc] init];

            PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform a removal transformation", ^{
            TestSubModel *subModel = [model.subModels objectAtIndex:0];

            PRORemovalTransformation *subModelsTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform a multiple transformation", ^{
            TestSubModel *subModel = [[TestSubModel alloc] init];

            PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
            PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];

            NSArray *transformations = [NSArray arrayWithObjects:insertionTransformation, removalTransformation, nil];
            PROMultipleTransformation *subModelsTransformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];

            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform an order transformation", ^{
            TestSubModel *firstSubModel = [[TestSubModel alloc] init];
            TestSubModel *secondSubModel = [[TestSubModel alloc] initWithName:@"foobar"];

            // set up the model with SubModels that we can reorder
            model.subModels = [NSArray arrayWithObjects:firstSubModel, secondSubModel, nil];

            PROOrderTransformation *subModelsTransformation = [[PROOrderTransformation alloc] initWithStartIndex:0 endIndex:1];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform a keyed + indexed transformation", ^{
            TestSubModel *subModel = [model.subModels objectAtIndex:0];

            PROTransformation *subModelTransformation = [subModel transformationForKey:PROKeyForObject(subModel, name) value:@"foobar"];
            PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];

            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform a keyed + indexed + unique transformation", ^{
            TestSubModel *subModel = [model.subModels objectAtIndex:0];

            TestSubModel *newSubModel = [[TestSubModel alloc] initWithName:@"foobar"];
            PROTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:subModel outputValue:newSubModel];

            PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];
        });

        it(@"should perform an insertion transformation followed by a removal transformation", ^{
            model.subModels = [NSArray arrayWithObjects:
                [[TestSubModel alloc] init],
                [[TestSubModel alloc] initWithName:@"foobar"],
                nil
            ];

            NSArray *originalSubModels = [model.subModels copy];

            // insertion
            TestSubModel *newModel = [[TestSubModel alloc] initWithName:@"fizzbuzz"];
            PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:newModel];
            PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:insertionTransformation forKey:PROKeyForObject(immutableModel, subModels)];

            __block NSError *error = nil;
            expect([model applyTransformation:modelTransformation error:&error]).toBeTruthy();
            expect(error).toBeNil();

            expect([model.subModels count]).toEqual(3);
            expect([model.subModels objectAtIndex:1]).toEqual([originalSubModels objectAtIndex:0]);
            expect([model.subModels objectAtIndex:2]).toEqual([originalSubModels objectAtIndex:1]);

            // removal
            NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, 2)];
            NSArray *removedObjects = [model.subModels objectsAtIndexes:indexSet];

            PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexSet expectedObjects:removedObjects];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:removalTransformation forKey:PROKeyForObject(immutableModel, subModels)];
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

                NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
                model.subModels = subModels;
            });

            it(@"should generate notification for inserting", ^{
                indexes = [NSIndexSet indexSetWithIndex:[[model subModels] count]];
                change = NSKeyValueChangeInsertion;

                [[model mutableArrayValueForKey:@"subModels"] addObject:[TestSubModel enabledSubModel]];
            });

            it(@"should generate notification for removing", ^{
                indexes = [NSIndexSet indexSetWithIndex:0];
                change = NSKeyValueChangeRemoval;

                [[model mutableArrayValueForKey:@"subModels"] removeObjectAtIndex:0];
            });

            it(@"should generate notification for replacement", ^{
                indexes = [NSIndexSet indexSetWithIndex:0];
                change = NSKeyValueChangeReplacement;

                [[model mutableArrayValueForKey:@"subModels"] replaceObjectAtIndex:0 withObject:[TestSubModel enabledSubModel]];
            });
        });

        describe(@"array mutation using transformations", ^{
            __block NSKeyValueChange change;
            __block NSIndexSet *indexes;

            __block PROTransformation *transformation;

            before(^{
                indexes = nil;
                change = 0;

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:model
                    keyPath:@"subModels"
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        observerInvoked = YES;

                        if (change != 0)
                            expect([[changes objectForKey:NSKeyValueChangeKindKey] integerValue]).toEqual(change);

                        if (indexes)
                            expect([changes objectForKey:NSKeyValueChangeIndexesKey]).toEqual(indexes);
                    }
                ];
            });

            after(^{
                expect([model applyTransformation:transformation error:NULL]).toBeTruthy();

                if (![[model name] isEqual:@"fizzbuzzfoobar"]) {
                    expect([model copy]).toEqual([transformation transform:immutableModel error:NULL]);
                }
            });

            it(@"should generate set notification for unique transformation", ^{
                change = NSKeyValueChangeSetting;

                NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
                transformation = [model transformationForKey:@"subModels" value:subModels];
            });

            it(@"should generate set notification for unique transformation with unsaved changes", ^{
                model.name = @"fizzbuzzfoobar";

                change = NSKeyValueChangeSetting;

                NSArray *subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
                transformation = [model transformationForKey:@"subModels" value:subModels];
            });

            it(@"should generate insertion notification for insertion transformation", ^{
                NSUInteger index = [[model subModels] count];

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeInsertion;

                id insertedObject = [TestSubModel enabledSubModel];
                PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:index object:insertedObject];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
            });

            it(@"should generate insertion notification for insertion transformation with unsaved changes", ^{
                model.name = @"fizzbuzzfoobar";

                NSUInteger index = [[model subModels] count];

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeInsertion;

                id insertedObject = [TestSubModel enabledSubModel];
                PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:index object:insertedObject];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
            });

            it(@"should generate removal notification for removal transformation", ^{
                NSUInteger index = 0;

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeRemoval;

                id removedObject = [[model subModels] objectAtIndex:0];
                PRORemovalTransformation *subModelsTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:index expectedObject:removedObject];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
            });

            it(@"should generate removal notification for removal transformation with unsaved changes", ^{
                model.name = @"fizzbuzzfoobar";

                NSUInteger index = 0;

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeRemoval;

                id removedObject = [[model subModels] objectAtIndex:0];
                PRORemovalTransformation *subModelsTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:index expectedObject:removedObject];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
            });

            it(@"should generate replacement notification for indexed transformation", ^{
                NSUInteger index = 0;

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeReplacement;

                id originalObject = [[model subModels] objectAtIndex:0];
                id replacementObject = [TestSubModel enabledSubModel];

                PROUniqueTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:originalObject outputValue:replacementObject];
                PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
            });

            it(@"should generate replacement notification for indexed transformation with unsaved changes", ^{
                model.name = @"fizzbuzzfoobar";

                NSUInteger index = 0;

                indexes = [NSIndexSet indexSetWithIndex:index];
                change = NSKeyValueChangeReplacement;

                id originalObject = [[model subModels] objectAtIndex:0];
                id replacementObject = [TestSubModel enabledSubModel];

                PROUniqueTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:originalObject outputValue:replacementObject];
                PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];
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

            model.name = newName;
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

            model.longValue = newValue;
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

            model.frame = newRect;
        });
    });

    describe(@"thread safety", ^{
        before(^{
            [[model mutableArrayValueForKey:@"subModels"] removeAllObjects];
        });

        it(@"should serialize sub-model insertions", ^{
            NSArray *newSubModels = [NSArray arrayWithObjects:
                [TestSubModel enabledSubModel],
                [TestSubModel enabledSubModel],
                [[TestSubModel alloc] init],
                [TestSubModel enabledSubModel],
                [[TestSubModel alloc] init],
                [[TestSubModel alloc] init],
                [[TestSubModel alloc] init],
                [TestSubModel enabledSubModel],
                [[TestSubModel alloc] init],
                [TestSubModel enabledSubModel],
                [TestSubModel enabledSubModel],
                [[TestSubModel alloc] init],
                [[TestSubModel alloc] init],
                nil
            ];

            NSMutableArray *mutableSubModels = [model mutableArrayValueForKey:@"subModels"];

            dispatch_apply(newSubModels.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
                TestSubModel *subModel = [newSubModels objectAtIndex:i];
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

    describe(@"transformation log", ^{
        __block PROModel *originalModel;

        // a transformation which can be performed to add to the log
        __block PROTransformation *transformation;

        before(^{
            originalModel = immutableModel;

            PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:[[TestSubModel alloc] init]];
            transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(immutableModel, subModels)];

            expect([transformation transform:immutableModel error:NULL]).not.toEqual(originalModel);
        });

        it(@"should default transformation log limit to 50", ^{
            expect(model.archivedTransformationLogLimit).toEqual(50);
        });

        it(@"should return a transformation log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;
            expect(logEntry).not.toBeNil();
        });

        it(@"should return a different transformation log entry after updating", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;

            model.subModels = [NSArray arrayWithObject:[TestSubModel enabledSubModel]];
            expect(model.transformationLogEntry).not.toEqual(logEntry);
        });

        it(@"should return an immutable model from a log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;
            
            TestSuperModel *restoredModel = [model modelWithTransformationLogEntry:logEntry];
            expect(restoredModel).not.toBeKindOf([PROMutableModel class]);
        });

        it(@"should return current model given current log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;
            
            TestSuperModel *restoredModel = [model modelWithTransformationLogEntry:logEntry];
            expect(restoredModel).toEqual(immutableModel);
        });

        it(@"should return model given archived log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;
            expect(logEntry).toSupportArchiving();

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:logEntry];
            PROTransformationLogEntry *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            
            TestSuperModel *restoredModel = [model modelWithTransformationLogEntry:decoded];
            expect(restoredModel).toEqual(immutableModel);
        });

        it(@"should return model given copied log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;
            expect(logEntry).toSupportCopying();
            
            TestSuperModel *restoredModel = [model modelWithTransformationLogEntry:logEntry.copy];
            expect(restoredModel).toEqual(immutableModel);
        });

        it(@"should return model given log entry after archiving", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:model];
            TestMutableSuperModel *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            
            TestSuperModel *restoredModel = [decoded modelWithTransformationLogEntry:logEntry];
            expect(restoredModel).toEqual(immutableModel);
            expect(restoredModel).toEqual(decoded.copy);
        });

        it(@"should return past model given past log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;

            model.name = @"fizzbuzz";
            
            // we should get back the model that existed at the time of the
            // log entry retrieval
            TestSuperModel *restoredModel = [model modelWithTransformationLogEntry:logEntry];
            expect(restoredModel).toEqual(originalModel);
            expect(restoredModel).not.toEqual(model);
        });

        it(@"should return past sub-model given past log entry to sub-model", ^{
            TestMutableSubModel *subModel = [model.subModels objectAtIndex:0];
            PROTransformationLogEntry *subEntry = subModel.transformationLogEntry;

            TestSubModel *originalSubModel = [subModel copy];

            subModel.enabled = YES;
            expect(subModel.enabled).toBeTruthy();
            expect(originalSubModel.enabled).toBeFalsy();

            expect([subModel modelWithTransformationLogEntry:subEntry]).toEqual(originalSubModel);
        });

        it(@"should restore past model given past log entry", ^{
            PROTransformationLogEntry *logEntry = model.transformationLogEntry;

            model.name = @"fizzbuzz";
            expect(model).not.toEqual(immutableModel);
            
            expect([model restoreTransformationLogEntry:logEntry]).toBeTruthy();
            expect(model).toEqual(immutableModel);
        });

        it(@"should restore future model given future log entry", ^{
            id pastLogEntry = model.transformationLogEntry;

            model.name = @"fizzbuzz";
            TestSuperModel *futureModel = [model copy];

            id futureLogEntry = model.transformationLogEntry;

            expect(pastLogEntry).not.toEqual(futureLogEntry);

            expect([model restoreTransformationLogEntry:pastLogEntry]).toBeTruthy();
            expect(model).toEqual(immutableModel);
            expect(model).not.toEqual(futureModel);

            expect([model restoreTransformationLogEntry:futureLogEntry]).toBeTruthy();
            expect(model).not.toEqual(immutableModel);
            expect(model).toEqual(futureModel);
        });

        it(@"should reuse model pointers when restoring a future log entry", ^{
            id pastLogEntry = model.transformationLogEntry;

            model.subModels = [NSArray arrayWithObjects:[TestSubModel enabledSubModel], [[TestSubModel alloc] initWithName:@"fizzbuzz"], nil];
            TestMutableSubModel *subModel = [model.subModels objectAtIndex:1];

            id futureLogEntry = model.transformationLogEntry;

            expect([model restoreTransformationLogEntry:pastLogEntry]).toBeTruthy();
            expect([model restoreTransformationLogEntry:futureLogEntry]).toBeTruthy();
            expect([model.subModels objectAtIndex:1] == subModel).toBeTruthy();
        });
    });

    describe(@"concurrency", ^{
        unsigned concurrentOperations = 10;

        before(^{
            NSMutableArray *mutableSubModels = [model mutableArrayValueForKey:@"subModels"];
            [mutableSubModels removeAllObjects];

            for (unsigned i = 0; i < concurrentOperations; ++i) {
                NSString *name = [NSString stringWithFormat:@"Sub model %u", i];
                TestSubModel *subModel = [[TestSubModel alloc] initWithName:name];
                expect(subModel).not.toBeNil();

                [mutableSubModels addObject:subModel];
            }

            model.subModels = mutableSubModels;
        });

        it(@"should serialize transformations from multiple threads", ^{
            NSString *newNamePrefix = @"new name ";

            dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                
                PROTransformation *subModelTransformation = [[model.subModels objectAtIndex:index] transformationForKey:@"name" value:newName];
                PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                PROKeyedTransformation *superModelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];

                expect([model applyTransformation:superModelTransformation error:NULL]).toBeTruthy();
                expect([[model.subModels objectAtIndex:index] name]).toEqual(newName);
            });

            // verify that every sub-model matches the name pattern after
            // the fact
            for (unsigned index = 0; index < concurrentOperations; ++index) {
                NSString *name = [[model.subModels objectAtIndex:index] name];
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                expect(name).toEqual(newName);
            }
        });

        it(@"should perform transformations on sub-models simultaneously", ^{
            NSString *newNamePrefix = @"new name ";

            dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                
                TestMutableSubModel *subModel = [model.subModels objectAtIndex:index];
                PROTransformation *subModelTransformation = [subModel transformationForKey:@"name" value:newName];

                expect([subModel applyTransformation:subModelTransformation error:NULL]).toBeTruthy();
                expect(subModel.name).toEqual(newName);
                expect([model.subModels objectAtIndex:index]).toEqual(subModel);
            });

            // verify that every sub-model matches the name pattern after
            // the fact
            for (unsigned index = 0; index < concurrentOperations; ++index) {
                NSString *name = [[model.subModels objectAtIndex:index] name];
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                expect(name).toEqual(newName);
            }
        });

        it(@"should perform transformations on super- and sub-models simultaneously", ^{
            NSString *newNamePrefix = @"new name ";

            dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                
                TestMutableSubModel *subModel = [model.subModels objectAtIndex:index];
                PROTransformation *subModelTransformation = [subModel transformationForKey:@"name" value:newName];

                if (index % 2 == 0) {
                    // perform on super model
                    PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                    PROKeyedTransformation *superModelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];

                    expect([model applyTransformation:superModelTransformation error:NULL]).toBeTruthy();
                } else {
                    // perform on sub model
                    expect([subModel applyTransformation:subModelTransformation error:NULL]).toBeTruthy();
                }

                expect(subModel.name).toEqual(newName);
                expect([model.subModels objectAtIndex:index]).toEqual(subModel);
            });

            // verify that every sub-model matches the name pattern after
            // the fact
            for (unsigned index = 0; index < concurrentOperations; ++index) {
                NSString *name = [[model.subModels objectAtIndex:index] name];
                NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                expect(name).toEqual(newName);
            }
        });
    });

SpecEnd

@interface TestSubModel ()
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, getter = isEnabled, readwrite) BOOL enabled;
@end

@implementation TestSubModel
@synthesize enabled = m_enabled;
@synthesize name = m_name;

+ (id)enabledSubModel; {
    NSDictionary *subModelDictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
    return [[self alloc] initWithDictionary:subModelDictionary error:NULL];
}

- (id)initWithName:(NSString *)name; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:name forKey:@"name"];
    return [self initWithDictionary:dictionary error:NULL];
}
@end

@interface TestSuperModel ()
@property (nonatomic, copy, readwrite) NSArray *subModels;
@property (nonatomic, copy, readwrite) NSArray *subArray;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, assign, readwrite) long longValue;
@property (nonatomic, assign, readwrite) CGRect frame;
@end

@implementation TestSuperModel
@synthesize subModels = m_subModels;
@synthesize subArray = m_subArray;
@synthesize name = m_name;
@synthesize longValue = m_longValue;
@synthesize frame = m_frame;

- (id)initWithSubModel:(TestSubModel *)subModel; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:subModel] forKey:@"subModels"];
    return [self initWithDictionary:dictionary error:NULL];
}

+ (NSDictionary *)modelClassesByKey {
    return [NSDictionary dictionaryWithObject:[TestSubModel class] forKey:PROKeyForClass(TestSuperModel, subModels)];
}

@end
