//
//  NSManagedObject+ConvenienceAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObject+ConvenienceAdditions.h"
#import "EXTSafeCategory.h"
#import "PROAssert.h"

@safecategory (NSManagedObject, ConvenienceAdditions)

+ (id)managedObjectWithContext:(NSManagedObjectContext *)context; {
    NSParameterAssert(context != nil);

    NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass(self) inManagedObjectContext:context];
    if (!PROAssert(entity, @"Could not find an entity for %@ in context %@", self, context))
        return nil;

    return [[self alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
}

+ (NSFetchRequest *)fetchRequest; {
    return [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
}

@end
