//
//  PROManagedObjectController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROManagedObjectController.h"
#import "EXTScope.h"
#import "NSUndoManager+UndoStackAdditions.h"
#import "PROAssert.h"
#import "PROKeyValueCodingMacros.h"

@interface PROManagedObjectController () {
    NSMutableSet *m_currentEditors;

    struct {
        unsigned groupsByEdit:1;
        unsigned saveOnCommitEditing:1;
        unsigned rollbackOnDiscardEditing:1;
        unsigned hasOpenUndoGroup:1;
        unsigned editing:1;
    } m_flags;
}

/**
 * Whether the receiver currently has an undo group open with its <undoManager>.
 */
@property (nonatomic, assign) BOOL hasOpenUndoGroup;

/**
 * Implements `-observationInfo` and `-setObservationInfo:` for improved
 * performance, per the `<NSKeyValueObserving>` protocol.
 */
@property (nonatomic) void *observationInfo;

/**
 * Attempts to commit editing on the given object, returning whether the commit
 * was successful.
 *
 * This method will attempt to find the best method to use for committing
 * changes, which may or may not be one of the methods in the `<NSEditor>`
 * protocol.
 *
 * @param editor An object implementing the `<NSEditor>` informal protocol.
 * @param error If not `NULL`, and this method returns `NO`, this may be set to
 * information about the error that occurred.
 */
- (BOOL)commitEditor:(id)editor error:(NSError **)error;
@end

@implementation PROManagedObjectController

#pragma mark Properties

@synthesize model = m_model;
@synthesize observationInfo = m_observationInfo;
@synthesize parentController = m_parentController;

- (BOOL)groupsByEdit {
    return m_flags.groupsByEdit;
}

- (void)setGroupsByEdit:(BOOL)value {
    m_flags.groupsByEdit = value;
}

- (BOOL)saveOnCommitEditing {
    return m_flags.saveOnCommitEditing;
}

- (void)setSaveOnCommitEditing:(BOOL)value {
    m_flags.saveOnCommitEditing = value;
}

- (BOOL)rollbackOnDiscardEditing {
    return m_flags.rollbackOnDiscardEditing;
}

- (void)setRollbackOnDiscardEditing:(BOOL)value {
    m_flags.rollbackOnDiscardEditing = value;
}

- (BOOL)hasOpenUndoGroup {
    return m_flags.hasOpenUndoGroup;
}

- (void)setHasOpenUndoGroup:(BOOL)value {
    m_flags.hasOpenUndoGroup = value;
}

- (BOOL)isEditing {
    return m_flags.editing;
}

- (void)setEditing:(BOOL)value {
    BOOL wasEditing = self.editing;
    m_flags.editing = value;

    // check the getter in case subclasses add additional criteria for being in
    // an editing state
    if (!wasEditing && self.editing) {
        if (self.groupsByEdit && self.undoManager) {
            [self.undoManager beginUndoGrouping];
            self.hasOpenUndoGroup = YES;
        }

        [self.parentController objectDidBeginEditing:self];
    } else if (wasEditing && !self.editing) {
        if (self.hasOpenUndoGroup) {
            if (PROAssert(self.undoManager.groupingLevel > 0, @"%@ has an open undo group, but undo manager %@ does not", self, self.undoManager)) {
                [self.undoManager endUndoGrouping];
            }

            self.hasOpenUndoGroup = NO;
        }

        [self.parentController objectDidEndEditing:self];
    }
}

- (NSUndoManager *)undoManager {
    return self.managedObjectContext.undoManager;
}

- (NSManagedObjectContext *)managedObjectContext {
    return self.model.managedObjectContext;
}

- (NSSet *)currentEditors {
    return [m_currentEditors copy];
}

- (void)addCurrentEditors:(NSSet *)editors {
    [m_currentEditors unionSet:editors];

    if (m_currentEditors.count)
        self.editing = YES;
}

- (void)removeCurrentEditors:(NSSet *)editors {
    [m_currentEditors minusSet:editors];

    if (!m_currentEditors.count)
        self.editing = NO;
}

#pragma mark Lifecycle

- (id)init {
    NSAssert(NO, @"Use -initWithModel: to initialize a %@", [self class]);
    return nil;
}

- (id)initWithModel:(NSManagedObject *)model; {
    if (!model)
        return nil;

    self = [super init];
    if (!self)
        return nil;

    m_model = model;
    m_currentEditors = [NSMutableSet set];

    self.groupsByEdit = YES;
    self.saveOnCommitEditing = YES;
    self.rollbackOnDiscardEditing = YES;

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self discardEditing];
    [self.undoManager removeAllActionsWithTarget:self];
}

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor; {
    NSMutableSet *editors = [self mutableSetValueForKey:PROKeyForObject(self, currentEditors)];
    [editors addObject:editor];
}

- (void)objectDidEndEditing:(id)editor; {
    NSMutableSet *editors = [self mutableSetValueForKey:PROKeyForObject(self, currentEditors)];
    [editors removeObject:editor];
}

#pragma mark NSEditor

- (void)discardEditing; {
    if (!self.editing)
        return;

    [self.currentEditors enumerateObjectsUsingBlock:^(id editor, BOOL *stop){
        if (PROAssert([editor respondsToSelector:@selector(discardEditing)], @"%@ does not implement <NSEditor>", editor))
            [editor discardEditing];
    }];

    /*
     * Editors are expected to invoke <objectDidEndEditing:> when they discard
     * their changes. If they don't, we assume that they haven't really finished
     * editing (for some reason).
     */
    self.editing = NO;
    
    // only rollback after cleaning up undo stuff
    if (self.rollbackOnDiscardEditing) {
        [self.managedObjectContext rollback];
    }
}

- (BOOL)commitEditing; {
    return [self commitEditingAndReturnError:NULL];
}

- (BOOL)commitEditingAndReturnError:(NSError **)errorPtr; {
    __block BOOL success = NO;

    [self commitEditingAndPerform:^(BOOL commitSuccessful, NSError *error){
        success = commitSuccessful;
        if (!commitSuccessful && errorPtr) {
            *errorPtr = error;
        }
    }];

    return success;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)selector contextInfo:(void *)contextInfo; {
    [self commitEditingAndPerform:^(BOOL commitSuccessful, NSError *error){
        if (!delegate)
            return;

        NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

        [invocation setTarget:delegate];
        [invocation setSelector:selector];

        __unsafe_unretained id editor = self;
        [invocation setArgument:&editor atIndex:2];
        [invocation setArgument:&commitSuccessful atIndex:3];

        void *context = contextInfo;
        [invocation setArgument:&context atIndex:4];

        [invocation invoke];
    }];
}

- (void)commitEditingAndPerform:(void (^)(BOOL commitSuccessful, NSError *error))block; {
    NSParameterAssert(block != nil);

    if (!self.editing) {
        block(YES, nil);
        return;
    }

    for (id editor in self.currentEditors) {
        NSError *error = nil;
        if (![self commitEditor:editor error:&error]) {
            block(NO, error);
            return;
        }
    }

    if (self.saveOnCommitEditing && self.managedObjectContext) {
        NSError *error = nil;
        if (![self.managedObjectContext save:&error]) {
            block(NO, error);
            return;
        }
    }

    self.editing = NO;
    block(YES, nil);
}

- (BOOL)commitEditor:(id)editor error:(NSError **)error; {
    if ([editor respondsToSelector:@selector(commitEditingAndReturnError:)]) {
        return [editor commitEditingAndReturnError:error];
    }

    if (!PROAssert([editor respondsToSelector:@selector(commitEditing)], @"%@ does not implement <NSEditor>", editor))
        return NO;

    return [editor commitEditing];
}

#pragma mark NSKeyValueCoding

+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>( model = %@, editing = %i )", [self class], self, self.model, (int)self.editing];
}

@end
