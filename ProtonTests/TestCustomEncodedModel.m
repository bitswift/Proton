//
//  TestCustomEncodedModel.m
//  Proton
//
//  Created by James Lawton on 3/15/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "TestCustomEncodedModel.h"
#import "NSManagedObject+PropertyListAdditions.h"
#import "NSArray+HigherOrderAdditions.h"

@implementation TestCustomEncodedModel

@dynamic unserialized;
@dynamic model;

- (id)propertyListRepresentation {
    NSArray *properties = [self.entity.properties filterUsingBlock:^ BOOL (id property) {
        return ![[property name] isEqualToString:@"unserialized"];
    }];
    return [self propertyListRepresentationIncludingProperties:properties];
}

@end
