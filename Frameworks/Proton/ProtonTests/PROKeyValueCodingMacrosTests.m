//
//  PROKeyValueCodingMacrosTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROKeyValueCodingMacrosTests.h"
#import <Proton/Proton.h>

@interface OtherClass : NSObject
@property (nonatomic, strong) NSString *otherClassProperty;
@property (nonatomic, assign) NSRange range;
@end

@interface PROKeyValueCodingMacrosTests ()
@property (nonatomic, strong) NSString *someProperty;
@property (nonatomic, assign) NSRange range;
@end

@implementation PROKeyValueCodingMacrosTests
@synthesize someProperty = m_someProperty;
@synthesize range = m_range;

- (void)testKeyForObject {
    NSString *propertyName = PROKeyForObject(self, someProperty);
    STAssertEqualObjects(propertyName, @"someProperty", @"");
}

- (void)testKeyForObjectUsingKeyPath {
    NSString *propertyName = PROKeyForObject(self, someProperty.length);
    STAssertEqualObjects(propertyName, @"someProperty.length", @"");
}

- (void)testKeyForObjectWithStruct {
    NSString *propertyName = PROKeyForObject(self, range);
    STAssertEqualObjects(propertyName, @"range", @"");
}

- (void)testKeyForClass {
    NSString *propertyName = PROKeyForClass(OtherClass, otherClassProperty);
    STAssertEqualObjects(propertyName, @"otherClassProperty", @"");
}

- (void)testKeyForClassUsingKeyPath {
    NSString *propertyName = PROKeyForClass(OtherClass, otherClassProperty.length);
    STAssertEqualObjects(propertyName, @"otherClassProperty.length", @"");
}

- (void)testKeyForClassWithStruct {
    NSString *propertyName = PROKeyForClass(OtherClass, range);
    STAssertEqualObjects(propertyName, @"range", @"");
}

@end
