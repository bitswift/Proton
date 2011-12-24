//
//  PROKeyValueCodingMacrosTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROKeyValueCodingMacrosTests.h"
#import <Proton/Proton.h>

@interface PROKeyValueCodingMacrosTests ()
@property (nonatomic, strong) NSString *someProperty;
@end

@implementation PROKeyValueCodingMacrosTests
@synthesize someProperty = m_someProperty;

- (void)testKeyForObject {
    NSString *propertyName = PROKeyForObject(self, someProperty);
    STAssertEqualObjects(propertyName, @"someProperty", @"");
}

- (void)testKeyForObjectUsingKeyPath {
    NSString *propertyName = PROKeyForObject(self, someProperty.length);
    STAssertEqualObjects(propertyName, @"someProperty.length", @"");
}

@end
