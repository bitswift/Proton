//
//  PROModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROModelTests.h"
#import <Proton/EXTScope.h>
#import <Proton/PROTransformation.h>

@interface TestModel : PROModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, getter = isEnabled) BOOL enabled;

+ (TestModel *)testInstance;
@end

@implementation PROModelTests

- (void)testPropertyKeys {
    STAssertNil([PROModel propertyKeys], @"");

    NSArray *keys = [NSArray arrayWithObjects:@"name", @"date", @"enabled", nil];
    STAssertEqualObjects([TestModel propertyKeys], keys, @"");
}

- (void)testInitialization {
    PROModel *model = [[PROModel alloc] init];
    STAssertNotNil(model, @"");
    STAssertEqualObjects(model.dictionaryValue, [NSDictionary dictionary], @"");
}

- (void)testSubclassInitialization {
    TestModel *model = [[TestModel alloc] init];
    STAssertNotNil(model, @"");

    NSDictionary *emptyDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNull null], @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    STAssertEqualObjects(model.dictionaryValue, emptyDictionary, @"");
}

- (void)testSubclassInitializationWithDictionary {
    NSDictionary *startingDict = [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];

    TestModel *model = [[TestModel alloc] initWithDictionary:startingDict];
    STAssertNotNil(model, @"");

    STAssertEqualObjects([model valueForKey:@"name"], @"foobar", @"");

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    STAssertEqualObjects(model.dictionaryValue, expectedDictionaryValue, @"");
}

- (void)testTransformValueForKey {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    TestModel *expectedObject = [[TestModel alloc] initWithDictionary:expectedDictionaryValue];

    [self verifyObject:model becomesObject:expectedObject afterTransformation:^{
        id result = [model transformValue:@"foobar" forKey:@"name"];
        STAssertEqualObjects(result, expectedObject, @"");
    }];
}

- (void)testTransformValuesForKeysWithDictionary {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *newDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate date], @"date",
        [NSNumber numberWithBool:YES], @"enabled",
        nil
    ];

    TestModel *expectedObject = [[TestModel alloc] initWithDictionary:newDictionary];

    [self verifyObject:model becomesObject:expectedObject afterTransformation:^{
        id result = [model transformValuesForKeysWithDictionary:newDictionary];
        STAssertEqualObjects(result, expectedObject, @"");
    }];
}

- (void)testEquality {
    PROModel *model = [TestModel testInstance];

    PROModel *equalModel = [TestModel testInstance];
    STAssertEqualObjects(model, equalModel, @"");

    PROModel *inequalModel = [[TestModel alloc] init];
    STAssertFalse([model isEqual:inequalModel], @"");
}

- (void)testCoding {
    PROModel *model = [TestModel testInstance];

    NSData *encodedModel = [NSKeyedArchiver archivedDataWithRootObject:model];
    PROModel *decodedModel = [NSKeyedUnarchiver unarchiveObjectWithData:encodedModel];

    STAssertEqualObjects(model, decodedModel, @"");
}

- (void)testCopying {
    PROModel *modelA = [TestModel testInstance];
    PROModel *modelB = [modelA copy];

    STAssertEqualObjects(modelA, modelB, @"");
}

- (void)testSetterTransformation {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    TestModel *expectedObject = [[TestModel alloc] initWithDictionary:expectedDictionaryValue];

    [self verifyObject:model becomesObject:expectedObject afterTransformation:^{
        [PROModel performTransformation:^{
            model.name = @"foobar";
        }];
    }];
}

- (void)testRecursiveSetterTransformation {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    TestModel *expectedObject = [[TestModel alloc] initWithDictionary:expectedDictionaryValue];

    [self verifyObject:model becomesObject:expectedObject afterTransformation:^{
        [PROModel performTransformation:^{
            [PROModel performTransformation:^{
                model.name = @"foobar";
            }];
        }];
    }];
}

- (void)testSetterTransformationWithNonObjectType {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNull null], @"name",
        [NSNull null], @"date",
        [NSNumber numberWithBool:YES], @"enabled",
        nil
    ];

    TestModel *expectedObject = [[TestModel alloc] initWithDictionary:expectedDictionaryValue];

    [self verifyObject:model becomesObject:expectedObject afterTransformation:^{
        [PROModel performTransformation:^{
            model.enabled = YES;
        }];
    }];
}

- (void)testSettingInvalidValue {
    TestModel *model = [[TestModel alloc] init];

    [self verifyObject:model becomesObject:nil afterTransformation:^{
        [PROModel performTransformation:^{
            // this name should be too short, according to the validation method we have
            model.name = @"foo";
        }];
    }];
}

- (void)verifyObject:(PROModel *)originalObject becomesObject:(PROModel *)transformedObject afterTransformation:(void (^)(void))transformationBlock; {
    NSDictionary *originalDictionaryValue = originalObject.dictionaryValue;

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:originalObject queue:nil usingBlock:^(NSNotification *notification){
        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        PROTransformation *performedTransformation = [userInfo objectForKey:PROModelTransformationKey];
        STAssertNotNil(performedTransformation, @"");

        // if the transformedObject is nil, this wasn't supposed to succeed
        if (!transformedObject)
            STFail(@"Transformation %@ on %@ should have failed", performedTransformation, originalObject);

        notificationSent = YES;

        // verify that the transformed object is correct
        PROModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");

        STAssertEqualObjects(newModel, transformedObject, @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    id failedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelTransformationFailedNotification object:originalObject queue:nil usingBlock:^(NSNotification *notification){
        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        PROTransformation *performedTransformation = [userInfo objectForKey:PROModelTransformationKey];
        STAssertNotNil(performedTransformation, @"");

        // if transformedObject is not nil, this was supposed to succeed
        if (transformedObject)
            STFail(@"Transformation %@ on %@ should have resulted in %@", performedTransformation, originalObject, transformedObject);

        notificationSent = YES;
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:failedObserver];
    };

    transformationBlock();
    
    // should've triggered the transformation notification
    STAssertTrue(notificationSent, @"");

    // the original object should not have changed
    STAssertEqualObjects(originalObject.dictionaryValue, originalDictionaryValue, @"");
}

@end

@implementation TestModel
@synthesize name = m_name;
@synthesize date = m_date;
@synthesize enabled = m_enabled;

- (BOOL)validateName:(NSString **)name error:(NSError **)error {
    // consider the name valid if its length is at least 5 characters (or if it
    // wasn't provided at all)
    return (*name == nil) || [*name length] >= 5;
}

+ (TestModel *)testInstance; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate dateWithTimeIntervalSinceReferenceDate:1000], @"date",
        [NSNumber numberWithBool:NO], @"enabled",
        nil
    ];

    return [[self alloc] initWithDictionary:dictionary];
}
@end
