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
@end

@interface TestSubModelController : PROModelController
@end

@interface TestSuperModel : PROModel
@property (copy) NSArray *subModels;
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

    // keep the KVO observer in its own scope, so that it's deallocated
    // before the controller
    [controller
        addObserverOwnedByObject:self
        forKeyPath:PROKeyForObject(controller, model)
        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
        usingBlock:^(NSDictionary *changes){
            STAssertEqualObjects([changes objectForKey:NSKeyValueChangeNewKey], newModel, @"");
            STAssertEqualObjects([changes objectForKey:NSKeyValueChangeOldKey], [NSNull null], @"");

            notificationSent = YES;
        }
    ];

    @onExit {
        [self removeAllOwnedObservers];
    };

    controller.model = newModel;
    STAssertTrue(notificationSent, @"");
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

@end

@implementation TestSubModel
@synthesize name = m_name;
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
@end

@implementation TestSuperModelController
@dynamic model;

@synthesize subModelControllers = m_subModelControllers;

- (void)setModel:(TestSuperModel *)model {
    [self.dispatchQueue runSynchronously:^{
        [super setModel:model];

        [m_subModelControllers removeAllObjects];

        [model.subModels enumerateObjectsUsingBlock:^(TestSubModel *subModel, NSUInteger index, BOOL *stop){
            TestSubModelController *controller = [[TestSubModelController alloc] initWithModel:subModel];
            [m_subModelControllers addObject:controller];
        }];
    }];
}

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_subModelControllers = [[NSMutableArray alloc] init];

    // set up a default model for the purposes of this test
    self.model = [[TestSuperModel alloc] init];
    return self;
}

- (Class)modelControllerClassAtKeyPath:(NSString *)modelControllersKeyPath; {
    return [TestSubModelController class];
}

- (NSString *)modelControllersKeyPathForModelKeyPath:(NSString *)modelsKeyPath; {
    if ([modelsKeyPath isEqualToString:PROKeyForObject(self.model, subModels)])
        return PROKeyForObject(self, subModelControllers);

    return nil;
}

- (void)insertObject:(TestSubModelController *)controller inSubModelControllersAtIndex:(NSUInteger)index; {
    [m_subModelControllers insertObject:controller atIndex:index];
}

- (void)removeObjectFromSubModelControllersAtIndex:(NSUInteger)index; {
    [m_subModelControllers removeObjectAtIndex:index];
}

@end

