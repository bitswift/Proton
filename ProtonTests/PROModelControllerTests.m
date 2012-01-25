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
    __block TestSuperModel *model = nil;
    __block TestSuperModelController *controller = nil;

    before(^{
        model = [[TestSuperModel alloc] initWithSubModel:[[TestSubModel alloc] init]];
        controller = [[TestSuperModelController alloc] initWithModel:model];
    });

    it(@"initializes without a model", ^{
        PROModelController *controller = [[PROModelController alloc] init];
        expect(controller).not.toBeNil();

        expect(controller.model).toBeNil();
        expect(controller.dispatchQueue).not.toBeNil();
        expect(controller.performingTransformation).toBeFalsy();
    });

    it(@"initializes without model", ^{
        PROModel *model = [[PROModel alloc] init];

        PROModelController *controller = [[PROModelController alloc] initWithModel:model];
        expect(controller).not.toBeNil();

        expect(controller.model).toEqual(model);
        expect(controller.dispatchQueue).not.toBeNil();
        expect(controller.performingTransformation).toBeFalsy();
    });
    
    describe(@"model controller subclass", ^{
        __block TestSuperModelController *controller = nil;
        __block PROKeyValueObserver *observer = nil;
        __block BOOL observerInvoked = NO;

        before(^{
            observerInvoked = NO;

            controller = [[TestSuperModelController alloc] init];
        });

        after(^{
            // make sure the observer is torn down before controller
            observer = nil;
            controller = nil;
        });

        it(@"should implement <NSCoding>", ^{
            expect(controller).toConformTo(@protocol(NSCoding));

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:controller];
            expect(encoded).not.toBeNil();

            TestSuperModelController *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];

            // equality comparisons (rightfully) don't work on model controllers
            expect(decoded.model).toEqual(controller.model);
            expect(decoded.subModelControllers.count).toEqual(controller.subModelControllers.count);

            // check the model of each sub-controller
            [controller.subModelControllers enumerateObjectsUsingBlock:^(TestSubModelController *subController, NSUInteger index, BOOL *stop){
                expect(subController.model).toEqual([[decoded.subModelControllers objectAtIndex:index] model]);
            }];
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

        describe(@"successful transformations", ^{
            __block PROTransformation *transformation;

            before(^{
                transformation = nil;
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
            });

            it(@"should perform an insertion transformation followed by a removal transformation", ^{
                NSArray *subModels = [NSArray arrayWithObjects:
                    [[TestSubModel alloc] init],
                    [[TestSubModel alloc] initWithName:@"foobar"],
                    nil
                ];

                controller.model = [[TestSuperModel alloc] initWithDictionary:[NSDictionary dictionaryWithObject:subModels forKey:PROKeyForObject(controller.model, subModels)] error:NULL];

                // insertion
                TestSubModel *newModel = [[TestSubModel alloc] initWithName:@"fizzbuzz"];
                PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:newModel];
                PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:insertionTransformation forKey:PROKeyForObject(controller.model, subModels)];

                __block NSError *error = nil;
                expect([controller performTransformation:modelTransformation error:&error]).toBeTruthy();
                expect(error).toBeNil();

                expect([controller.subModelControllers count]).toEqual(3);

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

