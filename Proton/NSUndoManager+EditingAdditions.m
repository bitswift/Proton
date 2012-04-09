//
//  NSUndoManager+EditingAdditions.m
//  Wireframes
//
//  Created by Josh Vera on 4/5/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+EditingAdditions.h"
#import "NSUndoManager+RegistrationAdditions.h"
#import "PROAssert.h"
#import <objc/runtime.h>

@implementation NSUndoManager (EditingAdditions)

- (void)setUndoManagerEditing:(BOOL)editing {
    id isEditing = objc_getAssociatedObject(self, @selector(setUndoManagerEditing:));
    if ([isEditing boolValue] == editing)
        return;

    objc_setAssociatedObject(self, @selector(setUndoManagerEditing:), [NSNumber numberWithBool:editing], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)isUndoManagerEditing {
    return [objc_getAssociatedObject(self, @selector(setUndoManagerEditing:)) boolValue];
}

- (BOOL)tryEditGrouping {
    return [self tryEditGroupingWithActionName:nil];
}

- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName {
    if ([self isUndoManagerEditing])
        return NO;

    self.undoManagerEditing = YES;
    [self beginUndoGrouping];

    if (actionName)
        self.actionName = actionName;

    return [self isUndoManagerEditing];
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
    PROAssert([self isUndoManagerEditing], @"%s called without an open edit undo grouping.", __func__);

    [self endUndoGrouping];
    self.undoManagerEditing = NO;
}

@end
