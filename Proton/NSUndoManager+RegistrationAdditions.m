//
//  NSUndoManager+RegistrationAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+RegistrationAdditions.h"
#import "NSUndoManager+UndoStackAdditions.h"
#import "EXTSafeCategory.h"

@interface NSObject (NSUndoManagerPerformBlockAdditions)
- (void)performUndoBlock:(void (^)(void))block;
@end

@safecategory (NSUndoManager, RegistrationAdditions)

- (BOOL)addGroupingWithActionName:(NSString *)actionName usingBlock:(BOOL (^)(void))block; {
    [self beginUndoGrouping];
    [self setActionName:actionName];
    BOOL result = block();
    [self endUndoGrouping];

    if (result) {
        return YES;
    } else {
        [self undoNestedGroupingWithoutRegisteringRedo];
        return NO;
    }
}

- (void)registerUndoWithBlock:(void (^)(void))block; {
    [self registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[block copy]];
}

- (void)registerUndoWithTarget:(id)target block:(void (^)(void))block; {
    NSAssert([target isKindOfClass:[NSObject class]], @"%@ must be an NSObject to be registered as the target for an undo block", target);
    
    [self registerUndoWithTarget:target selector:@selector(performUndoBlock:) object:[block copy]];
}

@end

@safecategory (NSObject, NSUndoManagerPerformBlockAdditions)
- (void)performUndoBlock:(void (^)(void))block; {
    block();
}

@end
