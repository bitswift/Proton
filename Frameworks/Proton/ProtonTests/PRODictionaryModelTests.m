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

    NSDictionary *expectedDictionaryValue = [NSDictionary dictionaryWithObject:@"foobar" forKey:@"name"];
    PRODictionaryModel *expectedModel = [[PRODictionaryModel alloc] initWithDictionary:expectedDictionaryValue];

    [self verifyObject:model becomesObject:expectedModel afterTransformation:^{
        [model setValue:@"foobar" forKey:@"name"];
    }];
}

- (void)testSetValuesForKeysWithDictionary {
    PRODictionaryModel *model = [[PRODictionaryModel alloc] init];

    NSDictionary *newDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"foobar", @"name",
        [NSDate date], @"date",
        nil
    ];

    PRODictionaryModel *expectedModel = [[PRODictionaryModel alloc] initWithDictionary:newDictionary];

    [self verifyObject:model becomesObject:expectedModel afterTransformation:^{
        [model setValuesForKeysWithDictionary:newDictionary];
    }];
}

- (void)testEquality {
    PRODictionaryModel *model = [self dictionaryModel];

    PRODictionaryModel *equalModel = [self dictionaryModel];
    STAssertEqualObjects(model, equalModel, @"");

    PRODictionaryModel *inequalModel = [[PRODictionaryModel alloc] init];
    STAssertFalse([model isEqual:inequalModel], @"");
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
