//
//  PROModelControllerTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

@interface TestSubModel : PROModel
@property (copy) NSString *name;

- (id)initWithName:(NSString *)name;
@end

@interface TestSubModelController : PROModelController
@end

@interface TestSuperModel : PROModel
@property (copy) NSArray *subModels;

- (id)initWithSubModel:(TestSubModel *)subModel;
@end

@interface TestSuperModelController : PROModelController
@property (copy) TestSuperModel *model;

@property (strong, readonly) NSMutableArray *subModelControllers;
@end

SpecBegin(PROModelController)
    it(@"initializes without a model", ^{
        PROModelController *controller = [[PROModelController alloc] init];
        expect(controller).not.toBeNil();

        expect(controller.model).toBeNil();
        expect(controller.performingTransformation).toBeFalsy();
        expect(controller.uniqueIdentifier).not.toBeNil();
    });

    it(@"initializes with a model", ^{
        PROModel *model = [[PROModel alloc] init];

        PROModelController *controller = [[PROModelController alloc] initWithModel:model];
        expect(controller).not.toBeNil();

        expect(controller.model).toEqual(model);
        expect(controller.performingTransformation).toBeFalsy();
        expect(controller.uniqueIdentifier).not.toBeNil();
    });

    it(@"should have a unique identifier", ^{
        PROModelController *firstController = [[PROModelController alloc] init];
        PROModelController *secondController = [[PROModelController alloc] init];

        expect(firstController.uniqueIdentifier).not.toEqual(secondController.uniqueIdentifier);
        expect(firstController).not.toEqual(secondController);
    });
    
    describe(@"model controller subclass", ^{
        __block TestSuperModelController *controller = nil;

        before(^{
            controller = [[TestSuperModelController alloc] init];
        });

        after(^{
            controller = nil;
        });

        it(@"should implement <NSCoding>", ^{
            expect(controller).toConformTo(@protocol(NSCoding));

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:controller];
            expect(encoded).not.toBeNil();

            TestSuperModelController *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            expect(decoded).toEqual(controller);

            // check the model of each sub-controller
            [controller.subModelControllers enumerateObjectsUsingBlock:^(TestSubModelController *subController, NSUInteger index, BOOL *stop){
                expect(subController.model).toEqual([[decoded.subModelControllers objectAtIndex:index] model]);
            }];
        });

        describe(@"key-value observation", ^{
            __block PROKeyValueObserver *observer = nil;
            __block BOOL observerInvoked = NO;

            before(^{
                observerInvoked = NO;
            });

            after(^{
                // make sure the observer is torn down before controller
                observer = nil;
            });

            it(@"should generate KVO notifications when replacing the model", ^{
                TestSuperModel *newModel = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];

                observer = [[PROKeyValueObserver alloc]
                    initWithTarget:controller
                    keyPath:PROKeyForObject(controller, model)
                    options:NSKeyValueObservingOptionNew
                    block:^(NSDictionary *changes){
                        STAssertEqualObjects([changes objectForKey:NSKeyValueChangeNewKey], newModel, @"");

                        observerInvoked = YES;
                    }
                ];

                controller.model = newModel;

                expect(controller.model).toEqual(newModel);
                expect(observerInvoked).toBeTruthy();
            });

            // TODO: add KVO tests for the various operations on the
            // modelControllers array
        });

        it(@"should not have a parent model controller by default", ^{
            expect(controller.parentModelController).toBeNil();
        });

        it(@"should have a parent model controller after being added to one", ^{
            controller.model = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];

            TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
            expect(subController.parentModelController).toEqual(controller);
        });

        it(@"should unset parent model controller after being removed from one", ^{
            controller.model = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];

            TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
            controller.model = [[TestSuperModel alloc] init];

            expect(subController.parentModelController).toBeNil();
        });

        describe(@"model controller with unique identifier", ^{
            before(^{
                controller.model = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];
            });

            it(@"should return a model controller for a matching unique identifier", ^{
                TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
                PROUniqueIdentifier *subControllerID = subController.uniqueIdentifier;

                expect([controller modelControllerWithIdentifier:subControllerID]).toEqual(subController);
            });

            it(@"should not return a model controller for a non-matching unique identifier", ^{
                expect([controller modelControllerWithIdentifier:[[PROUniqueIdentifier alloc] init]]).toBeNil();
            });
        });

        describe(@"successful transformations", ^{
            __block PROTransformation *transformation;

            // can be set to verify the exact model controllers at each index
            // unknown model controllers can be represented in here by NSNulls
            __block NSArray *expectedSubModelControllers;

            before(^{
                transformation = nil;
                expectedSubModelControllers = nil;
            });

            after(^{
                TestSuperModel *originalModel = controller.model;
                TestSuperModel *expectedModel = [transformation transform:originalModel error:NULL];
                expect(expectedModel).not.toBeNil();

                __block NSError *error = nil;
                expect([controller performTransformation:transformation error:&error]).toBeTruthy();
                expect(error).toBeNil();

                expect(controller.model).toEqual(expectedModel);
                expect(controller.subModelControllers.count).toEqual(expectedModel.subModels.count);

                // make sure that a SubModelController exists for each SubModel
                [controller.model.subModels enumerateObjectsUsingBlock:^(TestSubModel *subModel, NSUInteger index, BOOL *stop){
                    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:index];
                    expect(subController.model).toEqual(subModel);
                }];

                if (expectedSubModelControllers) {
                    [controller.subModelControllers enumerateObjectsUsingBlock:^(TestSubModelController *subController, NSUInteger index, BOOL *stop){
                        TestSubModelController *expectedController = [expectedSubModelControllers objectAtIndex:index];
                        if ([expectedController isEqual:[NSNull null]])
                            return;

                        expect(subController).toEqual(expectedController);
                    }];
                }
            });

            it(@"should perform a unique transformation", ^{
                TestSuperModel *newModel = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];

                transformation = [[PROUniqueTransformation alloc] initWithInputValue:controller.model outputValue:newModel];
            });
            
            it(@"should perform a keyed transformation", ^{
                NSArray *subModels = [NSArray arrayWithObject:[[TestSubModel alloc] init]];

                transformation = [controller.model transformationForKey:PROKeyForObject(controller.model, subModels) value:subModels];
            });

            it(@"should perform an insertion transformation", ^{
                TestSubModel *subModel = [[TestSubModel alloc] init];

                PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];
            });

            it(@"should perform a removal transformation", ^{
                TestSubModel *subModel = [[TestSubModel alloc] init];

                // set up the model with a SubModel that we can remove
                controller.model = [[TestSuperModel alloc] initWithSubModel:subModel];

                PRORemovalTransformation *subModelsTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];
            });

            it(@"should perform a multiple transformation", ^{
                TestSubModel *subModel = [[TestSubModel alloc] init];

                PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
                PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];

                NSArray *transformations = [NSArray arrayWithObjects:insertionTransformation, removalTransformation, nil];
                PROMultipleTransformation *subModelsTransformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];

                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];
            });

            it(@"should perform an order transformation", ^{
                TestSubModel *firstSubModel = [[TestSubModel alloc] init];
                TestSubModel *secondSubModel = [[TestSubModel alloc] initWithName:@"foobar"];
                NSArray *subModels = [NSArray arrayWithObjects:firstSubModel, secondSubModel, nil];

                NSDictionary *modelDictionary = [NSDictionary dictionaryWithObject:subModels forKey:@"subModels"];
                
                // set up the model with SubModels that we can reorder
                controller.model = [[TestSuperModel alloc] initWithDictionary:modelDictionary error:NULL];

                PROOrderTransformation *subModelsTransformation = [[PROOrderTransformation alloc] initWithStartIndex:0 endIndex:1];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

                expectedSubModelControllers = [NSArray arrayWithObjects:
                    [controller.subModelControllers objectAtIndex:1],
                    [controller.subModelControllers objectAtIndex:0],
                    nil
                ];
            });

            it(@"should perform a keyed + indexed transformation", ^{
                TestSubModel *subModel = [[TestSubModel alloc] init];
                TestSuperModel *model = [[TestSuperModel alloc] initWithSubModel:subModel];

                // set up the model with a SubModel that we can index to
                controller.model = model;

                TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
                STAssertEqualObjects(subController.model, subModel, @"");

                PROTransformation *subModelTransformation = [subModel transformationForKey:PROKeyForObject(subModel, name) value:@"foobar"];
                PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];

                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];
                expectedSubModelControllers = [NSArray arrayWithObject:subController];
            });

            it(@"should perform a keyed + indexed + unique transformation", ^{
                TestSubModel *subModel = [[TestSubModel alloc] init];
                TestSuperModel *model = [[TestSuperModel alloc] initWithSubModel:subModel];

                // set up the model with a SubModel that we can index to
                controller.model = model;

                TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
                STAssertEqualObjects(subController.model, subModel, @"");

                TestSubModel *newSubModel = [[TestSubModel alloc] initWithName:@"foobar"];
                PROTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:subModel outputValue:newSubModel];

                PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];

                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];
                expectedSubModelControllers = [NSArray arrayWithObject:subController];
            });

            it(@"should perform an insertion transformation followed by a removal transformation", ^{
                NSArray *subModels = [NSArray arrayWithObjects:
                    [[TestSubModel alloc] init],
                    [[TestSubModel alloc] initWithName:@"foobar"],
                    nil
                ];

                controller.model = [[TestSuperModel alloc] initWithDictionary:[NSDictionary dictionaryWithObject:subModels forKey:PROKeyForObject(controller.model, subModels)] error:NULL];

                NSArray *originalSubControllers = controller.subModelControllers;

                // insertion
                TestSubModel *newModel = [[TestSubModel alloc] initWithName:@"fizzbuzz"];
                PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:newModel];
                PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:insertionTransformation forKey:PROKeyForObject(controller.model, subModels)];

                __block NSError *error = nil;
                expect([controller performTransformation:modelTransformation error:&error]).toBeTruthy();
                expect(error).toBeNil();

                expect([controller.subModelControllers count]).toEqual(3);
                expect([controller.subModelControllers objectAtIndex:1]).toEqual([originalSubControllers objectAtIndex:0]);
                expect([controller.subModelControllers objectAtIndex:2]).toEqual([originalSubControllers objectAtIndex:1]);

                // removal
                NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, 2)];
                NSArray *removedObjects = [controller.model.subModels objectsAtIndexes:indexSet];

                PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndexes:indexSet expectedObjects:removedObjects];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:removalTransformation forKey:PROKeyForObject(controller.model, subModels)];
            });
        });

        it(@"should not perform an invalid transformation", ^{
            TestSuperModel *originalModel = controller.model;

            TestSubModel *subModel = [[TestSubModel alloc] init];
            TestSuperModel *newModel = [[TestSuperModel alloc] initWithSubModel:subModel];

            PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:newModel outputValue:originalModel];

            __block NSError *error = nil;
            expect([controller performTransformation:transformation error:&error]).toBeFalsy();

            expect(error.domain).toEqual([PROTransformation errorDomain]);
            expect(error.code).toEqual(PROTransformationErrorMismatchedInput);
        });

        describe(@"transformation log", ^{
            __block PROModel *originalModel;

            // a transformation which can be performed to add to the log
            __block PROTransformation *transformation;

            before(^{
                originalModel = controller.model;

                PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:[[TestSubModel alloc] init]];
                transformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

                expect([transformation transform:controller.model error:NULL]).not.toEqual(originalModel);
            });

            it(@"should default transformation log limit to 50", ^{
                expect(controller.archivedTransformationLogLimit).toEqual(50);
            });

            it(@"should return transformation log entry without model pointer", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];

                expect(logEntry).not.toBeNil();
                expect(logEntry.modelControllerIdentifier).toEqual(controller.uniqueIdentifier);
            });

            it(@"should return transformation log entry with model pointer", ^{
                TestSuperModel *model = nil;
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:&model];

                expect(logEntry).not.toBeNil();
                expect(logEntry.modelControllerIdentifier).toEqual(controller.uniqueIdentifier);
                expect(model).toEqual(controller.model);
            });

            it(@"should return different transformation log entry after replacing model", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];

                controller.model = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];
                expect([controller transformationLogEntryWithModelPointer:NULL]).not.toEqual(logEntry);
            });

            it(@"should return current model given current log entry", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];
                
                TestSuperModel *model = [controller modelWithTransformationLogEntry:logEntry];
                expect(model).toEqual(controller.model);
            });

            it(@"should return model given archived log entry", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];
                expect(logEntry).toSupportArchiving();

                NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:logEntry];
                PROModelControllerTransformationLogEntry *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
                
                TestSuperModel *model = [controller modelWithTransformationLogEntry:decoded];
                expect(model).toEqual(controller.model);
            });

            it(@"should return model given copied log entry", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];
                expect(logEntry).toSupportCopying();
                
                TestSuperModel *model = [controller modelWithTransformationLogEntry:[logEntry copy]];
                expect(model).toEqual(controller.model);
            });

            it(@"should return model given log entry after archiving", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];

                NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:controller];
                TestSuperModelController *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
                
                TestSuperModel *model = [decoded modelWithTransformationLogEntry:logEntry];
                expect(model).toEqual(controller.model);
                expect(model).toEqual(decoded.model);
            });

            it(@"should return past model given past log entry", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];

                // perform a transformation, to update the log
                expect([controller performTransformation:transformation error:NULL]).toBeTruthy();
                
                // we should get back the model that existed at the time of the
                // log entry retrieval
                TestSuperModel *model = [controller modelWithTransformationLogEntry:logEntry];
                expect(model).toEqual(originalModel);
                expect(model).not.toEqual(controller.model);
            });

            it(@"should restore past model given past log entry", ^{
                PROModelControllerTransformationLogEntry *logEntry = [controller transformationLogEntryWithModelPointer:NULL];

                // perform a transformation, to update the log
                expect([controller performTransformation:transformation error:NULL]).toBeTruthy();
                
                expect([controller restoreModelFromTransformationLogEntry:logEntry]).toBeTruthy();
                expect(controller.model).toEqual(originalModel);
            });

            it(@"should restore future model given future log entry", ^{
                id pastLogEntry = [controller transformationLogEntryWithModelPointer:NULL];

                expect([controller performTransformation:transformation error:NULL]).toBeTruthy();
                id futureLogEntry = [controller transformationLogEntryWithModelPointer:NULL];

                expect(pastLogEntry).not.toEqual(futureLogEntry);

                expect([controller restoreModelFromTransformationLogEntry:pastLogEntry]).toBeTruthy();
                expect(controller.model).toEqual(originalModel);

                expect([controller restoreModelFromTransformationLogEntry:futureLogEntry]).toBeTruthy();
                expect(controller.model).not.toEqual(originalModel);
            });

            it(@"should reuse model controller UUIDs when restoring a future log entry", ^{
                id pastLogEntry = [controller transformationLogEntryWithModelPointer:NULL];

                expect([controller performTransformation:transformation error:NULL]).toBeTruthy();

                id futureLogEntry = [controller transformationLogEntryWithModelPointer:NULL];
                NSArray *controllerIDs = [controller.subModelControllers mapUsingBlock:^(PROModelController *modelController){
                    return modelController.uniqueIdentifier;
                }];

                expect([controller restoreModelFromTransformationLogEntry:pastLogEntry]).toBeTruthy();
                expect([controller restoreModelFromTransformationLogEntry:futureLogEntry]).toBeTruthy();

                NSArray *newIDs = [controller.subModelControllers mapUsingBlock:^(PROModelController *modelController){
                    return modelController.uniqueIdentifier;
                }];

                expect(controllerIDs).toEqual(newIDs);
            });
        });

        describe(@"concurrency", ^{
            unsigned concurrentOperations = 10;

            __block NSArray *subModels;

            before(^{
                NSMutableArray *mutableSubModels = [[NSMutableArray alloc] init];

                for (unsigned i = 0; i < concurrentOperations; ++i) {
                    NSString *name = [NSString stringWithFormat:@"Sub model %u", i];
                    TestSubModel *subModel = [[TestSubModel alloc] initWithName:name];
                    expect(subModel).not.toBeNil();

                    [mutableSubModels addObject:subModel];
                }

                subModels = mutableSubModels;

                NSDictionary *dictionary = [NSDictionary dictionaryWithObject:subModels forKey:@"subModels"];
                TestSuperModel *superModel = [[TestSuperModel alloc] initWithDictionary:dictionary error:NULL];
                expect(superModel).not.toBeNil();

                controller.model = superModel;
            });

            it(@"should serialize transformations from multiple threads", ^{
                NSString *newNamePrefix = @"new name ";

                dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                    
                    PROTransformation *subModelTransformation = [[subModels objectAtIndex:index] transformationForKey:@"name" value:newName];
                    PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                    PROKeyedTransformation *superModelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];

                    expect([controller performTransformation:superModelTransformation error:NULL]).toBeTruthy();
                    expect([[[controller.model subModels] objectAtIndex:index] name]).toEqual(newName);

                    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:index];
                    expect([subController.model name]).toEqual(newName);
                });

                // verify that every sub-model matches the name pattern after
                // the fact
                for (unsigned index = 0; index < concurrentOperations; ++index) {
                    NSString *name = [[[controller.model subModels] objectAtIndex:index] name];
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                    expect(name).toEqual(newName);
                }
            });

            it(@"should perform transformations on managed model controllers simultaneously", ^{
                NSString *newNamePrefix = @"new name ";

                dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                    
                    PROTransformation *subModelTransformation = [[subModels objectAtIndex:index] transformationForKey:@"name" value:newName];
                    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:index];

                    expect([subController performTransformation:subModelTransformation error:NULL]).toBeTruthy();
                    expect([subController.model name]).toEqual(newName);
                    expect([[[controller.model subModels] objectAtIndex:index] name]).toEqual(newName);
                });

                // verify that every sub-model matches the name pattern after
                // the fact
                for (unsigned index = 0; index < concurrentOperations; ++index) {
                    NSString *name = [[[controller.model subModels] objectAtIndex:index] name];
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                    expect(name).toEqual(newName);
                }
            });

            it(@"should perform transformations on managing and managed model controllers simultaneously", ^{
                NSString *newNamePrefix = @"new name ";

                dispatch_apply(concurrentOperations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%zu", index];
                    
                    PROTransformation *subModelTransformation = [[subModels objectAtIndex:index] transformationForKey:@"name" value:newName];
                    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:index];

                    if (index % 2 == 0) {
                        // perform on super controller
                        PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:index transformation:subModelTransformation];
                        PROKeyedTransformation *superModelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:@"subModels"];

                        expect([controller performTransformation:superModelTransformation error:NULL]).toBeTruthy();
                    } else {
                        // perform on sub controller
                        expect([subController performTransformation:subModelTransformation error:NULL]).toBeTruthy();
                    }

                    expect([subController.model name]).toEqual(newName);
                    expect([[[controller.model subModels] objectAtIndex:index] name]).toEqual(newName);
                });

                // verify that every sub-model matches the name pattern after
                // the fact
                for (unsigned index = 0; index < concurrentOperations; ++index) {
                    NSString *name = [[[controller.model subModels] objectAtIndex:index] name];
                    NSString *newName = [newNamePrefix stringByAppendingFormat:@"%u", index];

                    expect(name).toEqual(newName);
                }
            });
        });
    });

SpecEnd

@implementation TestSubModel
@synthesize name = m_name;

- (id)initWithName:(NSString *)name {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:name forKey:PROKeyForObject(self, name)];
    return [self initWithDictionary:dictionary error:NULL];
}

@end

@implementation TestSubModelController
@end

@implementation TestSuperModel
@synthesize subModels = m_subModels;

- (id)initWithSubModel:(TestSubModel *)subModel; {
    NSArray *subModels = [NSArray arrayWithObject:subModel];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:subModels forKey:PROKeyForObject(self, subModels)];
    return [self initWithDictionary:dictionary error:NULL];
}
@end

@implementation TestSuperModelController
@dynamic model;
@dynamic subModelControllers;

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    // set up a default model for the purposes of this test
    self.model = [[TestSuperModel alloc] init];
    return self;
}

+ (NSDictionary *)modelControllerClassesByKey; {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [TestSubModelController class], PROKeyForClass(TestSuperModelController, subModelControllers),
        nil
    ];
}

+ (NSDictionary *)modelControllerKeysByModelKeyPath; {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        PROKeyForClass(TestSuperModelController, subModelControllers), PROKeyForClass(TestSuperModel, subModels),
        nil
    ];
}

@end

