//
//  NSUndoManager+UndoStackAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+UndoStackAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSUndoManager, UndoStackAdditions)

- (void)undoNestedGroupingWithoutRegisteringRedo; {
    [self disableUndoRegistration];
    [self undoNestedGroup];
    [self enableUndoRegistration];
}

@end
