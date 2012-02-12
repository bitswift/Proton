//
//  NSUndoManager+RegistrationAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+RegistrationAdditions.h"
#import "EXTSafeCategory.h"
#import "NSObject+ComparisonAdditions.h"
#import "NSUndoManager+UndoStackAdditions.h"
#import <objc/runtime.h>

/**
 * A key for associating block actions with the undo manager they're registered
 * with.
 *
 * The corresponding value will be an `NSArray` containing
 * <PROUndoManagerBlockAction> instances.
 */
static char * const PROUndoManagerBlockActionsKey = "PROUndoManagerBlockActions";

/**
 * Extensions to `NSObject` to support performing blocks via invocations
 * targeted at the receiver.
 */
@interface NSObject (NSUndoManagerPerformBlockAdditions)

/**
 * Executes the given block.
 */
- (void)performUndoBlock:(void (^)(void))block;
@end

/**
 * Stores undo and redo blocks associated with a target, to ensure that the
 * blocks remain valid for as long as they're registered with an undo manager.
 */
@interface PROUndoManagerBlockAction : NSObject <NSCopying>

/**
 * Initializes the receiver with the given properties.
 *
 * @param target The target for the undo action. This may be `nil`.
 * @param undoBlock The undo block for the action. This cannot be `nil`.
 * @param redoBlock The redo block for the action. This may be `nil`.
 */
- (id)initWithTarget:(id)target undoBlock:(id)undoBlock redoBlock:(id)redoBlock;

/**
 * The target associated with this block action, or `nil` if there is no target.
 */
@property (nonatomic, unsafe_unretained, readonly) id target;

/**
 * The undo block for this action.
 */
@property (nonatomic, copy, readonly) id undoBlock;

/**
 * The redo block for this action, or `nil` if there is no redo block.
 */
@property (nonatomic, copy, readonly) id redoBlock;
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
    [self registerUndoWithTarget:self block:block];
}

- (void)registerUndoWithTarget:(id)target block:(void (^)(void))block; {
    NSAssert([target isKindOfClass:[NSObject class]], @"%@ must be an NSObject to be registered as the target for an undo block", target);
    NSParameterAssert(block != nil);

    [self registerUndoWithTarget:target selector:@selector(performUndoBlock:) object:[block copy]];
}

- (void)registerUndoWithBlock:(void (^)(void))undoBlock redoBlock:(void (^)(void))redoBlock; {
    [self registerUndoWithTarget:self block:undoBlock redoBlock:redoBlock];
}

- (void)registerUndoWithTarget:(id)target block:(void (^)(void))undoBlock redoBlock:(void (^)(void))redoBlock; {
    void (^copiedRedoBlock)(void) = [redoBlock copy];
    void (^copiedUndoBlock)(void) = [undoBlock copy];

    __block __unsafe_unretained id weakRecursiveRedoBlock;
    __block __unsafe_unretained id weakRecursiveUndoBlock;

    __weak NSUndoManager *weakSelf = self;
    __unsafe_unretained id weakTarget = target;

    id recursiveUndoBlock = [^{
        [weakSelf registerUndoWithTarget:weakTarget block:weakRecursiveRedoBlock];

        copiedUndoBlock();
    } copy];

    id recursiveRedoBlock = [^{
        [weakSelf registerUndoWithTarget:weakTarget block:weakRecursiveUndoBlock];

        copiedRedoBlock();
    } copy];

    weakRecursiveRedoBlock = recursiveRedoBlock;
    weakRecursiveUndoBlock = recursiveUndoBlock;

    NSMutableArray *actions = objc_getAssociatedObject(self, PROUndoManagerBlockActionsKey);
    if (!actions) {
        actions = [[NSMutableArray alloc] init];

        objc_setAssociatedObject(self, PROUndoManagerBlockActionsKey, actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    PROUndoManagerBlockAction *action = [[PROUndoManagerBlockAction alloc] initWithTarget:target undoBlock:recursiveUndoBlock redoBlock:recursiveRedoBlock];
    [actions addObject:action];

    [self registerUndoWithTarget:target block:recursiveUndoBlock];
}

@end

@implementation NSUndoManager (UnsafeRegistrationAdditions)

+ (void)load {
    // update -removeAllActions and -removeAllActionsWithTarget: to properly
    // remove block-based actions
    SEL removeAllActionsSelector = @selector(removeAllActions);
    SEL removeAllActionsWithTargetSelector = @selector(removeAllActionsWithTarget:);

    Method removeAllActions = class_getInstanceMethod(self, removeAllActionsSelector);
    Method removeAllActionsWithTarget = class_getInstanceMethod(self, removeAllActionsWithTargetSelector);

    void (*removeAllActionsIMP)(id, SEL) = (void (*)(id, SEL))method_getImplementation(removeAllActions);
    void (*removeAllActionsWithTargetIMP)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(removeAllActionsWithTarget);

    id newRemoveAllActions = [^(NSUndoManager *self){
        // destroy the array of block-based actions, if it exists
        objc_setAssociatedObject(self, PROUndoManagerBlockActionsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        removeAllActionsIMP(self, removeAllActionsSelector);
    } copy];

    id newRemoveAllActionsWithTarget = [^(NSUndoManager *self, id target){
        // this may be getting called (directly or indirectly) from the target's
        // -dealloc method, so don't retain it in here
        __unsafe_unretained id weakTarget = target;

        NSMutableArray *actions = objc_getAssociatedObject(self, PROUndoManagerBlockActionsKey);

        if (actions) {
            NSIndexSet *actionIndexesToRemove = [actions indexesOfObjectsPassingTest:^ BOOL (PROUndoManagerBlockAction *action, NSUInteger index, BOOL *stop){
                return action.target == weakTarget;
            }];

            if ([actionIndexesToRemove count] == [actions count]) {
                // destroy the whole array
                objc_setAssociatedObject(self, PROUndoManagerBlockActionsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                [actions removeObjectsAtIndexes:actionIndexesToRemove];
            }
        }

        removeAllActionsWithTargetIMP(self, removeAllActionsWithTargetSelector, weakTarget);
    } copy];

    IMP newRemoveAllActionsIMP = imp_implementationWithBlock((__bridge_retained void *)newRemoveAllActions);
    IMP newRemoveAllActionsWithTargetIMP = imp_implementationWithBlock((__bridge_retained void *)newRemoveAllActionsWithTarget);

    class_replaceMethod(self, removeAllActionsSelector, newRemoveAllActionsIMP, method_getTypeEncoding(removeAllActions));
    class_replaceMethod(self, removeAllActionsWithTargetSelector, newRemoveAllActionsWithTargetIMP, method_getTypeEncoding(removeAllActionsWithTarget));
}

@end

@safecategory (NSObject, NSUndoManagerPerformBlockAdditions)
- (void)performUndoBlock:(void (^)(void))block; {
    block();
}

@end

@implementation PROUndoManagerBlockAction

#pragma mark Properties

@synthesize target = m_target;
@synthesize undoBlock = m_undoBlock;
@synthesize redoBlock = m_redoBlock;

#pragma mark Initialization

- (id)initWithTarget:(id)target undoBlock:(id)undoBlock redoBlock:(id)redoBlock; {
    NSParameterAssert(undoBlock != nil);

    self = [super init];
    if (!self)
        return nil;

    m_target = target;
    m_undoBlock = [undoBlock copy];
    m_redoBlock = [redoBlock copy];
    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark NSObject overrides

- (NSUInteger)hash {
    return [self.undoBlock hash];
}

- (BOOL)isEqual:(PROUndoManagerBlockAction *)action {
    if (![action isKindOfClass:[PROUndoManagerBlockAction class]])
        return NO;

    if (self.target != action.target)
        return NO;

    if (!NSEqualObjects(self.undoBlock, action.undoBlock))
        return NO;

    if (!NSEqualObjects(self.redoBlock, action.redoBlock))
        return NO;

    return YES;
}

@end
