//
//  PRODictionaryModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 14.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRODictionaryModelTests.h"
#import <Proton/EXTScope.h>
#import <Proton/PRODictionaryModel.h>

@interface PRODictionaryModelTests ()
- (PRODictionaryModel *)dictionaryModel;
@end

@implementation PRODictionaryModelTests

- (PRODictionaryModel *)dictionaryModel; {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate dateWithTimeIntervalSinceReferenceDate:1000], @"date",
        nil
    ];

    return [[PRODictionaryModel alloc] initWithDictionary:dictionary];
}

- (void)testPropertyKeys {
    STAssertNil([PRODictionaryModel propertyKeys], @"");
}

- (void)testInitialization {
    PRODictionaryModel *model = [[PRODictionaryModel alloc] init];
    STAssertNotNil(model, @"");
    STAssertEqualObjects(model.dictionaryValue, [NSDictionary dictionary], @"");
}

- (void)testInitializationWithDictionary {
    NSDate *date = [NSDate date];

    NSDictionary *dictionaryValue = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        date, @"date",
        nil
    ];

    PRODictionaryModel *model = [[PRODictionaryModel alloc] initWithDictionary:dictionaryValue];
    STAssertNotNil(model, @"");

    STAssertEqualObjects([model valueForKey:@"name"], @"foobar", @"");
    STAssertEqualObjects([model valueForKey:@"date"], date, @"");
    STAssertEqualObjects(model.dictionaryValue, dictionaryValue, @"");
}

- (void)testSetValueForKey {
    PRODictionaryModel *model = [[PRODictionaryModel alloc] init];

    __block BOOL notificationSent = NO;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PROModelDidTransformNotification object:model queue:nil usingBlock:^(NSNotification *notification){
        notificationSent = YES;

        NSDictionary *userInfo = notification.userInfo;
        STAssertNotNil(userInfo, @"");

        // verify that the transformation performed is in the userInfo
        // dictionary
        STAssertNotNil([userInfo objectForKey:PROModelTransformationKey], @"");

        // verify that the transformed object is correct
        PRODictionaryModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
        STAssertNotNil(newModel, @"");

        NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];
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
    PRODictionaryModel *model = [[PRODictionaryModel alloc] init];

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
        PRODictionaryModel *newModel = [userInfo objectForKey:PROModelTransformedObjectKey];
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
    PRODictionaryModel *modelA = [self dictionaryModel];
    PRODictionaryModel *modelB = [self dictionaryModel];

    STAssertEqualObjects(modelA, modelB, @"");
}

- (void)testCoding {
    PRODictionaryModel *model = [self dictionaryModel];

    NSData *encodedModel = [NSKeyedArchiver archivedDataWithRootObject:model];
    PRODictionaryModel *decodedModel = [NSKeyedUnarchiver unarchiveObjectWithData:encodedModel];

    STAssertEqualObjects(model, decodedModel, @"");
}

- (void)testCopying {
    PRODictionaryModel *modelA = [self dictionaryModel];
    PRODictionaryModel *modelB = [modelA copy];

    STAssertEqualObjects(modelA, modelB, @"");
}

@end
