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
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSDate *date;

+ (TestModel *)testInstance;
@end

@implementation PROModelTests

- (void)testPropertyKeys {
    STAssertNil([PROModel propertyKeys], @"");

    NSArray *keys = [NSArray arrayWithObjects:@"name", @"date", nil];
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
}

- (void)testSetValuesForKeysWithDictionary {
    TestModel *model = [[TestModel alloc] init];

    NSDictionary *newDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate date], @"date",
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

@end

@interface TestModel ()
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSDate *date;
@end

@implementation TestModel
@synthesize name;
@synthesize date;

+ (TestModel *)testInstance; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate dateWithTimeIntervalSinceReferenceDate:1000], @"date",
        nil
    ];

    return [[self alloc] initWithDictionary:dictionary];
}
@end
