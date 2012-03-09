//
//  TestModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "TestModel.h"
#import "TestSubModel.h"
#import "NSManagedObject+PropertyListAdditions.h"


@implementation TestModel

@dynamic name;
@dynamic value;
@dynamic subModels;

@synthesize initWasCalledOnTestModel = m_initWasCalledOnTestModel;

- (id)initWithPropertyListRepresentation:(NSDictionary *)propertyList insertIntoManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithPropertyListRepresentation:propertyList insertIntoManagedObjectContext:context];
    m_initWasCalledOnTestModel = YES;
    return self;
}

@end
