//
//  TestCustomModelWithoutEncodedName.m
//  Proton
//
//  Created by Josh Vera on 4/3/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "TestCustomModelWithoutEncodedName.h"
#import "NSManagedObject+PropertyListAdditions.h"

@implementation TestCustomModelWithoutEncodedName

- (BOOL)shouldEncodePropertyInPropertyListRepresentation:(NSPropertyDescription *)property {
    BOOL success = [super shouldEncodePropertyInPropertyListRepresentation:property];
    return success && ![property.name isEqualToString:@"name"];
}

@end
