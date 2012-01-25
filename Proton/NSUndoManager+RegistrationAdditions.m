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

@safecategory (NSUndoManager, RegistrationAdditions)

- (BOOL)registerGroupWithActionName:(NSString *)actionName block:(BOOL (^)(void))block undoBlock:(void (^)(void))undoBlock; {
    // ARC has a tendency to go crazy with deeply-nested blocks, so copy
    // everything now
    BOOL (^copiedBlock)(void) = [block copy];
    void (^copiedUndoBlock)(void) = [undoBlock copy];

    [self beginUndoGrouping];
    [self setActionName:actionName];

    [[self prepareWithInvocationTarget:self]
        registerGroupWithActionName:actionName
        block:[^{
            copiedUndoBlock();
            return YES;
        } copy]

        undoBlock:[^{
            copiedBlock();
        } copy]
    ];

    BOOL result = copiedBlock();

    [self endUndoGrouping];

    if (result) {
        return YES;
    } else {
        [self undoNestedGroupingWithoutRegisteringRedo];
        return NO;
    }
}

@end
