//
//  PROModelControllerTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 05.01.12.
//  Copyright (c) 2012 Emerald Lark. All rights reserved.
//

#import "PROModelControllerTests.h"
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

@implementation PROModelControllerTests

- (void)testInitialization {
    PROModelController *controller = [[PROModelController alloc] init];
    STAssertNotNil(controller, @"");

    STAssertNil(controller.model, @"");
    STAssertNotNil(controller.dispatchQueue, @"");
    STAssertFalse(controller.performingTransformation, @"");
}

- (void)testInitializationWithModel {
    PROModel *model = [[PROModel alloc] init];

    PROModelController *controller = [[PROModelController alloc] initWithModel:model];
    STAssertNotNil(controller, @"");

    STAssertEqualObjects(controller.model, model, @"");
    STAssertNotNil(controller.dispatchQueue, @"");
    STAssertFalse(controller.performingTransformation, @"");
}

- (void)testModelKVONotifications {
    PROModelController *controller = [[PROModelController alloc] init];

    __block BOOL notificationSent = NO;

    PROModel *newModel = [[PROModel alloc] init];

    {
        // keep the KVO observer in its own scope, so that it's deallocated
        // before the controller
        id observer = [[PROKeyValueObserver alloc]
            initWithTarget:controller
            keyPath:PROKeyForObject(controller, model)
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            block:^(NSDictionary *changes){
                STAssertEqualObjects([changes objectForKey:NSKeyValueChangeNewKey], newModel, @"");
                STAssertEqualObjects([changes objectForKey:NSKeyValueChangeOldKey], [NSNull null], @"");

                notificationSent = YES;
            }
        ];

        // shut up about not using 'observer'
        [observer self];

        controller.model = newModel;
        STAssertTrue(notificationSent, @"");
    }
}

- (void)testPerformingUniqueTransformation {
    TestSuperModelController *controller = [[TestSuperModelController alloc] init];

    TestSubModel *subModel = [[TestSubModel alloc] init];
    TestSuperModel *newModel = [controller.model transformValueForKey:PROKeyForObject(controller.model, subModels) toValue:[NSArray arrayWithObject:subModel]];

    PROUniqueTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:controller.model outputValue:newModel];

    STAssertTrue([controller performTransformation:transformation], @"");
    STAssertEqualObjects(controller.model, newModel, @"");

    // make sure that a SubModelController exists for the new SubModel
    STAssertEquals([controller.subModelControllers count], (NSUInteger)1, @"");
    STAssertEqualObjects([[controller.subModelControllers objectAtIndex:0] model], subModel, @"");
}

- (void)testPerformingKeyedTransformation {
    TestSuperModelController *controller = [[TestSuperModelController alloc] init];

    TestSubModel *subModel = [[TestSubModel alloc] init];
    NSArray *subModels = [NSArray arrayWithObject:subModel];

    // this will create a transformation keyed on 'subModels'
    PROTransformation *transformation = [controller.model transformationForKey:PROKeyForObject(controller.model, subModels) value:subModels];

    STAssertTrue([controller performTransformation:transformation], @"");
    STAssertEqualObjects(controller.model.subModels, subModels, @"");

    // make sure that a SubModelController exists for the new SubModel
    STAssertEquals([controller.subModelControllers count], (NSUInteger)1, @"");
    STAssertEqualObjects([[controller.subModelControllers objectAtIndex:0] model], subModel, @"");
}

- (void)testPerformingInsertionTransformation {
    TestSuperModelController *controller = [[TestSuperModelController alloc] init];

    TestSubModel *subModel = [[TestSubModel alloc] init];

    PROInsertionTransformation *subModelsTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");
    STAssertEqualObjects(controller.model.subModels, [NSArray arrayWithObject:subModel], @"");

    // make sure that a SubModelController exists for the new SubModel
    STAssertEquals([controller.subModelControllers count], (NSUInteger)1, @"");
    STAssertEqualObjects([[controller.subModelControllers objectAtIndex:0] model], subModel, @"");
}

- (void)testPerformingRemovalTransformation {
    TestSubModel *subModel = [[TestSubModel alloc] init];
    TestSuperModel *model = [[TestSuperModel alloc] initWithSubModel:subModel];

    TestSuperModelController *controller = [[TestSuperModelController alloc] initWithModel:model];

    PRORemovalTransformation *subModelsTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];
    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");
    STAssertEqualObjects(controller.model.subModels, [NSArray array], @"");

    // make sure that the SubModelController was removed
    STAssertEqualObjects(controller.subModelControllers, [NSArray array], @"");
}

- (void)testPerformingMultipleTransformation {
    TestSuperModelController *controller = [[TestSuperModelController alloc] init];

    TestSubModel *subModel = [[TestSubModel alloc] init];

    PROInsertionTransformation *insertionTransformation = [[PROInsertionTransformation alloc] initWithInsertionIndex:0 object:subModel];
    PRORemovalTransformation *removalTransformation = [[PRORemovalTransformation alloc] initWithRemovalIndex:0 expectedObject:subModel];

    NSArray *transformations = [NSArray arrayWithObjects:insertionTransformation, removalTransformation, nil];
    PROMultipleTransformation *subModelsTransformation = [[PROMultipleTransformation alloc] initWithTransformations:transformations];

    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");
    STAssertEqualObjects(controller.model.subModels, [NSArray array], @"");

    // make sure that no SubModelController exists
    STAssertEqualObjects(controller.subModelControllers, [NSArray array], @"");
}

- (void)testPerformingOrderTransformation {
    TestSubModel *firstSubModel = [[TestSubModel alloc] init];
    TestSubModel *secondSubModel = [[TestSubModel alloc] initWithName:@"foobar"];
    NSArray *subModels = [NSArray arrayWithObjects:firstSubModel, secondSubModel, nil];

    NSDictionary *modelDictionary = [NSDictionary dictionaryWithObject:subModels forKey:@"subModels"];
    TestSuperModel *model = [[TestSuperModel alloc] initWithDictionary:modelDictionary];

    TestSuperModelController *controller = [[TestSuperModelController alloc] initWithModel:model];

    PROOrderTransformation *subModelsTransformation = [[PROOrderTransformation alloc] initWithStartIndex:0 endIndex:1];
    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");

    NSArray *expectedSubModels = [NSArray arrayWithObjects:secondSubModel, firstSubModel, nil];
    STAssertEqualObjects(controller.model.subModels, expectedSubModels, @"");

    // make sure that the SubModelControllers were also reordered
    STAssertEqualObjects([[controller.subModelControllers objectAtIndex:0] model], [expectedSubModels objectAtIndex:0], @"");
    STAssertEqualObjects([[controller.subModelControllers objectAtIndex:1] model], [expectedSubModels objectAtIndex:1], @"");
}

- (void)testPerformingIndexedKeyedTransformation {
    TestSubModel *subModel = [[TestSubModel alloc] init];
    TestSuperModel *model = [[TestSuperModel alloc] initWithSubModel:subModel];

    TestSuperModelController *controller = [[TestSuperModelController alloc] initWithModel:model];

    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
    STAssertEqualObjects(subController.model, subModel, @"");

    PROTransformation *subModelTransformation = [subModel transformationForKey:PROKeyForObject(subModel, name) value:@"foobar"];
    PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];

    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");

    // make sure the SubModelController changed
    //
    // in a real app, the SuperModelController should change too, but that
    // requires the application to implement KVO
    STAssertEqualObjects([subController.model name], @"foobar", @"");
    STAssertFalse([subController.model isEqual:subModel], @"");
}

- (void)testPerformingIndexedUniqueTransformation {
    TestSubModel *subModel = [[TestSubModel alloc] init];
    TestSuperModel *model = [[TestSuperModel alloc] initWithSubModel:subModel];

    TestSuperModelController *controller = [[TestSuperModelController alloc] initWithModel:model];

    TestSubModelController *subController = [controller.subModelControllers objectAtIndex:0];
    STAssertEqualObjects(subController.model, subModel, @"");

    TestSubModel *newSubModel = [[TestSubModel alloc] initWithName:@"foobar"];
    PROTransformation *subModelTransformation = [[PROUniqueTransformation alloc] initWithInputValue:subModel outputValue:newSubModel];

    PROIndexedTransformation *subModelsTransformation = [[PROIndexedTransformation alloc] initWithIndex:0 transformation:subModelTransformation];

    PROKeyedTransformation *modelTransformation = [[PROKeyedTransformation alloc] initWithTransformation:subModelsTransformation forKey:PROKeyForObject(controller.model, subModels)];

    STAssertTrue([controller performTransformation:modelTransformation], @"");

    // make sure the SubModelController changed
    //
    // in a real app, the SuperModelController should change too, but that
    // requires the application to implement KVO
    STAssertEqualObjects([subController.model name], @"foobar", @"");
    STAssertFalse([subController.model isEqual:subModel], @"");
}

@end

@implementation TestSubModel
@synthesize name = m_name;

- (id)initWithName:(NSString *)name {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:name forKey:PROKeyForObject(self, name)];
    return [self initWithDictionary:dictionary];
}

@end

@implementation TestSubModelController
@end

@implementation TestSuperModel
@synthesize subModels = m_subModels;

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super initWithDictionary:dictionary];
    if (!self)
        return nil;

    if (!m_subModels) {
        // create an empty array so that we can easily insert into it with our
        // tests
        m_subModels = [[NSArray alloc] init];
    }

    return self;
}

- (id)initWithSubModel:(TestSubModel *)subModel; {
    NSArray *subModels = [NSArray arrayWithObject:subModel];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:subModels forKey:PROKeyForObject(self, subModels)];
    return [self initWithDictionary:dictionary];
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

