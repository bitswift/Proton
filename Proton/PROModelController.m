//
//  PROModelController.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelController.h"

@implementation PROModelController

#pragma mark Properties

@synthesize model = m_model;
@synthesize groupsByEdit = m_groupsByEdit;
@synthesize saveOnCommitEditing = m_saveOnCommitEditing;
@synthesize rollbackOnDiscardEditing = m_rollbackOnDiscardEditing;
@synthesize currentEditors = m_currentEditors;

- (NSUndoManager *)undoManager {
    return self.managedObjectContext.undoManager;
}

- (NSManagedObjectContext *)managedObjectContext {
    return self.model.managedObjectContext;
}

- (BOOL)isEditing {
    return self.currentEditors.count > 0;
}

#pragma mark Lifecycle

- (id)initWithModel:(NSManagedObject *)model; {
    return nil;
}

#pragma mark Model Controllers

- (PROModelController *)modelControllerForModel:(NSManagedObject *)model; {
    return nil;
}

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor; {
}

- (void)objectDidEndEditing:(id)editor; {
}

#pragma mark NSEditor

- (void)discardEditing; {
}

- (BOOL)commitEditing; {
    return NO;
}

- (BOOL)commitEditingAndReturnError:(NSError **)error; {
    return NO;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo; {
}

- (void)commitEditingAndPerform:(void (^)(BOOL commitSuccessful, NSError *error))block; {
}

@end
