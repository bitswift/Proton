//
//  TestCustomModelWithoutEncodedName.m
//  Proton
//
//  Created by Josh Vera on 4/3/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "TestCustomModelWithoutEncodedName.h"
#import "NSManagedObject+PropertyListAdditions.h"
#import "PROKeyValueCodingMacros.h"

@implementation TestCustomModelWithoutEncodedName
@dynamic number;

- (BOOL)shouldEncodePropertyInPropertyListRepresentation:(NSPropertyDescription *)property {
    if ([property.name isEqualToString:PROKeyForObject(self, name)])
        return NO;

    return [super shouldEncodePropertyInPropertyListRepresentation:property];
}

@end
