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
#import <objc/runtime.h>

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

- (void)performBlock:(void (^)(void))block registeringUndoWithBlock:(void (^)(void))undoBlock; {
    [self performWithTarget:self block:block registeringUndoWithBlock:undoBlock];
}

- (void)performWithTarget:(id)target block:(void (^)(void))block registeringUndoWithBlock:(void (^)(void))undoBlock; {
    BOOL (^copiedRedoBlock)(void) = [block copy];
    void (^copiedUndoBlock)(void) = [undoBlock copy];

    __block __unsafe_unretained id weakRecursiveRedoBlock;
    __block __unsafe_unretained id weakRecursiveUndoBlock;

    __weak NSUndoManager *weakSelf = self;
    __unsafe_unretained id weakTarget = target;

    id recursiveUndoBlock = [^{
        [weakSelf registerUndoWithTarget:weakTarget block:weakRecursiveRedoBlock];

        copiedUndoBlock();
    } copy];

    void (^recursiveRedoBlock)(void) = [^{
        [weakSelf registerUndoWithTarget:weakTarget block:weakRecursiveUndoBlock];

        copiedRedoBlock();
    } copy];

    weakRecursiveRedoBlock = recursiveRedoBlock;
    weakRecursiveUndoBlock = recursiveUndoBlock;

    // TODO: these should be associated with the lifecycle of 'target', and
    // freed when actions are removed from 'target'
    objc_setAssociatedObject(self, (__bridge void *)recursiveRedoBlock, recursiveRedoBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, (__bridge void *)recursiveUndoBlock, recursiveUndoBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);

    // start it off with a redo
    recursiveRedoBlock();
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
