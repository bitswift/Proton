//
//  PROModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROModelTests.h"
#import <Proton/PROModel.h>
#import <Proton/EXTScope.h>

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

- (void)testSetValueForKey {
    TestModel *model = [[TestModel alloc] init];

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");

        // verify that the transformed object is correct
        TestModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");

        NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foobar", @"name",
            [NSNull null], @"date",
            [NSNumber numberWithBool:NO], @"enabled",
            nil
        ];

        STAssertEqualObjects(newModel.dictionaryValue, expectedDictionaryValue, @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    [model setValue:@"foobar" forKey:@"name"];
    
    // setting a value should've triggered the transformation notification
    STAssertTrue(notificationSent, @"");

    // setting a value should not have modified the original object
    STAssertNil([model valueForKey:@"name"], @"");
    STAssertNil([model valueForKey:@"date"], @"");
    STAssertEqualObjects([model valueForKey:@"enabled"], [NSNumber numberWithBool:NO], @"");
}

- (void)testSetValuesForKeysWithDictionary {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *newDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate date], @"date",
        [NSNumber numberWithBool:YES], @"enabled",
        nil
    ];

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");

        // verify that the transformed object is correct
        TestModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");
        STAssertEqualObjects(newModel.dictionaryValue, newDictionary, @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    [model setValuesForKeysWithDictionary:newDictionary];
    
    // setting a value should've triggered the transformation notification
    STAssertTrue(notificationSent, @"");

    // setting a value should not have modified the original object
    STAssertNil([model valueForKey:@"name"], @"");
    STAssertNil([model valueForKey:@"date"], @"");
    STAssertEqualObjects([model valueForKey:@"enabled"], [NSNumber numberWithBool:NO], @"");
}

- (void)testEquality {
    PROModel *modelA = [TestModel testInstance];
    PROModel *modelB = [TestModel testInstance];

    STAssertEqualObjects(modelA, modelB, @"");
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

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");

        // verify that the transformed object is correct
        TestModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");

        NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foobar", @"name",
            [NSNull null], @"date",
            [NSNumber numberWithBool:NO], @"enabled",
            nil
        ];

        STAssertEqualObjects(newModel.dictionaryValue, expectedDictionaryValue, @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    model.name = @"foobar";
    
    // setting a value should've triggered the transformation notification
    STAssertTrue(notificationSent, @"");

    // setting a value should not have modified the original object
    STAssertNil([model valueForKey:@"name"], @"");
    STAssertNil([model valueForKey:@"date"], @"");
    STAssertEqualObjects([model valueForKey:@"enabled"], [NSNumber numberWithBool:NO], @"");
}

- (void)testSetterTransformationWithNonObjectType {
    TestModel *model = [[TestModel alloc] init];

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");

        // verify that the transformed object is correct
        TestModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");

        NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNull null], @"name",
            [NSNull null], @"date",
            [NSNumber numberWithBool:YES], @"enabled",
            nil
        ];

        STAssertEqualObjects(newModel.dictionaryValue, expectedDictionaryValue, @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    model.enabled = YES;
    
    // setting a value should've triggered the transformation notification
    STAssertTrue(notificationSent, @"");

    // setting a value should not have modified the original object
    STAssertNil([model valueForKey:@"name"], @"");
    STAssertNil([model valueForKey:@"date"], @"");
    STAssertEqualObjects([model valueForKey:@"enabled"], [NSNumber numberWithBool:NO], @"");
}

- (void)testSettingInvalidValue {
    TestModel *model = [[TestModel alloc] init];

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelTransformationFailedNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation attempted is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");
    }];

    @onExit {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    };

    // this name should be too short, according to the validation method we have
    model.name = @"foo";
    
    // setting the value to something invalid should've triggered the failure
    // notification
    STAssertTrue(notificationSent, @"");

    // attempting to set an invalid value should not have modified the original object
    STAssertNil([model valueForKey:@"name"], @"");
    STAssertNil([model valueForKey:@"date"], @"");
    STAssertEqualObjects([model valueForKey:@"enabled"], [NSNumber numberWithBool:NO], @"");
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
