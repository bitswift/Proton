//
//  NSManagedObjectContext+ConvenienceAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSManagedObjectContext+ConvenienceAdditions.h"
#import "EXTSafeCategory.h"
#import "EXTScope.h"

@safecategory (NSManagedObjectContext, ConvenienceAdditions)
- (void)refreshAllObjectsMergingChanges:(BOOL)mergeChanges; {
    NSSet *objects = [self.registeredObjects copy];

    [objects enumerateObjectsUsingBlock:^(NSManagedObject *object, BOOL *stop){
        [self refreshObject:object mergeChanges:mergeChanges];
    }];
}

- (BOOL)saveWithMergePolicy:(NSMergePolicy *)mergePolicy error:(NSError **)error; {
    NSMergePolicy *originalPolicy = self.mergePolicy;
    self.mergePolicy = mergePolicy;

    BOOL success = [self save:error];
    self.mergePolicy = originalPolicy;

    return success;
}

- (void)performBlockWithDisabledUndoAndWait:(void (^)(void))block; {
    [self performBlockAndWait:^{
        [self processPendingChanges];
        [self.undoManager disableUndoRegistration];

        @onExit {
            [self processPendingChanges];
            [self.undoManager enableUndoRegistration];
        };

        block();
    }];
}

@end
