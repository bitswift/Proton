//
//  PROModelTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROModelTests.h"
#import <Proton/EXTScope.h>
#import <Proton/PROKeyedTransformation.h>
#import <Proton/PROModel.h>
#import <Proton/PROTransformation.h>
#import <Proton/PROUniqueTransformation.h>

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

    id result = [model transformValueForKey:@"name" toValue:@"foobar"];
    STAssertEqualObjects(result, expectedObject, @"");
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

    id result = [model transformValuesForKeysWithDictionary:newDictionary];
    STAssertEqualObjects(result, expectedObject, @"");
}

- (void)testTransformationForKey {
    TestModel *model = [TestModel testInstance];

    PROKeyedTransformation *transformation = [model transformationForKey:@"name" value:@"fizzbuzz"];
    STAssertNotNil(transformation, @"");
    STAssertTrue([transformation isKindOfClass:[PROKeyedTransformation class]], @"");

    // should be just the one transformation we specified
    STAssertTrue([transformation.valueTransformations count] == 1, @"");

    // the only transformation should be a unique transformation from 'foobar'
    // to 'fizzbuzz'
    PROUniqueTransformation *uniqueTransformation = [transformation.valueTransformations objectForKey:@"name"];
    STAssertTrue([uniqueTransformation isKindOfClass:[PROUniqueTransformation class]], @"");

    STAssertEqualObjects(uniqueTransformation.inputValue, model.name, @"");
    STAssertEqualObjects(uniqueTransformation.outputValue, @"fizzbuzz", @"");
}

- (void)testTransformationForKeysWithDictionary {
    TestModel *model = [TestModel testInstance];

    NSDate *now = [[NSDate alloc] init];

    NSDictionary *changes = [NSDictionary dictionaryWithObjectsAndKeys:
        @"fizzbuzz", @"name",
        now, @"date",
        nil
    ];

    PROKeyedTransformation *transformation = [model transformationForKeysWithDictionary:changes];
    STAssertNotNil(transformation, @"");
    STAssertTrue([transformation isKindOfClass:[PROKeyedTransformation class]], @"");

    // should be just the two transformations we specified
    STAssertTrue([transformation.valueTransformations count] == 2, @"");

    {
        // we should have a unique transformation from 'foobar' to 'fizzbuzz'
        PROUniqueTransformation *uniqueTransformation = [transformation.valueTransformations objectForKey:@"name"];
        STAssertTrue([uniqueTransformation isKindOfClass:[PROUniqueTransformation class]], @"");

        STAssertEqualObjects(uniqueTransformation.inputValue, model.name, @"");
        STAssertEqualObjects(uniqueTransformation.outputValue, @"fizzbuzz", @"");
    }

    {
        // we should have a unique transformation from the default date to now
        PROUniqueTransformation *uniqueTransformation = [transformation.valueTransformations objectForKey:@"date"];
        STAssertTrue([uniqueTransformation isKindOfClass:[PROUniqueTransformation class]], @"");

        STAssertEqualObjects(uniqueTransformation.inputValue, model.date, @"");
        STAssertEqualObjects(uniqueTransformation.outputValue, now, @"");
    }
}

- (void)testInvalidTransformationForKey {
    TestModel *model = [TestModel testInstance];

    // an empty name won't pass TestModel's validation method
    PROKeyedTransformation *transformation = [model transformationForKey:@"name" value:@""];
    STAssertNil(transformation, @"");
}

- (void)testInvalidTransformationForKeysWithDictionary {
    TestModel *model = [TestModel testInstance];

    NSDictionary *changes = [NSDictionary dictionaryWithObjectsAndKeys:
        @"", @"name",
        [NSDate date], @"date",
        nil
    ];

    // an empty name won't pass TestModel's validation method
    PROKeyedTransformation *transformation = [model transformationForKeysWithDictionary:changes];
    STAssertNil(transformation, @"");
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
