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

@end

@implementation TestSubModel
@synthesize name = m_name;
@end

@implementation TestSubModelController
@end

@implementation TestSuperModel
@synthesize subModels = m_subModels;
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

