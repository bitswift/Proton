//
//  NSUndoManager+EditingAdditions.m
//  Wireframes
//
//  Created by Josh Vera on 4/5/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+EditingAdditions.h"

static BOOL PRONSUndoManagerIsEditing = NO;

@implementation NSUndoManager (EditingAdditions)

- (BOOL)tryEditGrouping {
    if (PRONSUndoManagerIsEditing)
        return NO;

    PRONSUndoManagerIsEditing = YES;
    [self beginUndoGrouping];
    return PRONSUndoManagerIsEditing;
}

- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName {
    if ([self tryEditGrouping] || [self.undoActionName isEqualToString:actionName]) {
        self.actionName = actionName;
        return YES;
    }

    return NO;
}

- (BOOL)tryEditGroupingUsingBlock:(void (^)(void))block {
    return [self tryEditGroupingWithActionName:nil usingBlock:block];
}

- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName usingBlock:(void (^)(void))block {
    if (![self tryEditGroupingWithActionName:actionName])
        return NO;

    block();

    [self endEditGrouping];

    return YES;
}

- (void)endEditGrouping {
    [self endUndoGrouping];
    PRONSUndoManagerIsEditing = NO;
}

@end
