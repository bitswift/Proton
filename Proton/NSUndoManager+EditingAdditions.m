//
//  NSUndoManager+EditingAdditions.m
//  Wireframes
//
//  Created by Josh Vera on 4/5/12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+EditingAdditions.h"
#import "NSUndoManager+RegistrationAdditions.h"
#import "EXTSafeCategory.h"
#import "PROAssert.h"
#import <objc/runtime.h>

@safecategory(NSUndoManager, EditingAdditions)

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
    if ([self isUndoManagerEditing])
        return NO;

    self.undoManagerEditing = YES;
    [self beginUndoGrouping];

    return YES;
}

- (BOOL)tryEditGroupingUsingBlock:(void (^)(void))block {
    return [self tryEditGroupingWithActionName:nil usingBlock:block];
}

- (BOOL)tryEditGroupingWithActionName:(NSString *)actionName usingBlock:(void (^)(void))block {
    if (![self tryEditGrouping])
        return NO;

    block();

    self.actionName = actionName;
    [self endEditGrouping];
    return YES;
}

- (void)endEditGrouping {
    if (!PROAssert([self isUndoManagerEditing], @"%s called without an open edit undo grouping.", __func__))
        return;

    [self endUndoGrouping];
    self.undoManagerEditing = NO;
}

@end
