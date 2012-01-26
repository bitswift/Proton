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

- (BOOL)addGroupingWithActionName:(NSString *)actionName performingBlock:(BOOL (^)(void))block undoBlock:(void (^)(void))undoBlock; {
    BOOL (^copiedRedoBlock)(void) = [block copy];
    void (^copiedUndoBlock)(void) = [undoBlock copy];

    __block __unsafe_unretained id weakRecursiveRedoBlock;
    __block __unsafe_unretained id weakRecursiveUndoBlock;

    __weak NSUndoManager *weakSelf = self;

    id recursiveUndoBlock = [^{
        [weakSelf beginUndoGrouping];
        [weakSelf setActionName:actionName];
        [weakSelf registerUndoWithBlock:weakRecursiveRedoBlock];
        [weakSelf endUndoGrouping];

        copiedUndoBlock();
    } copy];

    id recursiveRedoBlock = [^{
        [weakSelf beginUndoGrouping];
        [weakSelf setActionName:actionName];
        [weakSelf registerUndoWithBlock:weakRecursiveUndoBlock];
        [weakSelf endUndoGrouping];

        copiedRedoBlock();
    } copy];

    weakRecursiveRedoBlock = recursiveRedoBlock;
    weakRecursiveUndoBlock = recursiveUndoBlock;

    // these should only be deallocated when the undo manager is
    objc_setAssociatedObject(self, (__bridge void *)recursiveRedoBlock, recursiveRedoBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, (__bridge void *)recursiveUndoBlock, recursiveUndoBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);

    return [self addGroupingWithActionName:actionName usingBlock:^{
        [weakSelf registerUndoWithBlock:weakRecursiveUndoBlock];
        return copiedRedoBlock();
    }];
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
