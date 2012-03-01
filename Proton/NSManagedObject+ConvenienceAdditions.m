//
//  NSManagedObject+ConvenienceAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObject+ConvenienceAdditions.h"
#import "EXTSafeCategory.h"
#import "NSError+ValidationAdditions.h"
#import "NSObject+ComparisonAdditions.h"
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

- (BOOL)validateWithError:(NSError **)error usingBlocks:(BOOL (^)(void))firstBlock, ...; {
    NSParameterAssert(firstBlock);

    BOOL success = firstBlock();

    va_list args;
    va_start(args, firstBlock);

    for (;;) {
        __unsafe_unretained id unsafeBlock = va_arg(args, id);
        if (!unsafeBlock) {
            // out of arguments
            break;
        }

        BOOL (^block)(void) = unsafeBlock;

        // save the current error so that we'll know what this specific block sets
        NSError *savedError = nil;
        if (error)
            savedError = *error;
        
        if (block()) {
            // don't manipulate the error object if the block succeeded
            continue;
        } else {
            success = NO;
        }

        if (!error || !savedError)
            continue;

        if (!(*error)) {
            // the block cleared out the error for some reason, so restore it
            *error = savedError;
        } else if (savedError != *error) {
            // combine the two
            *error = [savedError multipleValidationErrorByAddingError:*error];
        }
    }

    va_end(args);
    return success;
}

@end
