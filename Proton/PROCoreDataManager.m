//
//  PROCoreDataManager.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROCoreDataManager.h"
#import "EXTScope.h"
#import <objc/runtime.h>

/**
 * Associated object key on an `NSManagedObjectContext`, associated with an
 * `NSNotificationCenter` observer block that is called when that context saves.
 *
 * This is used to merge changes into the <[PROCoreDataManager
 * mainThreadContext]> automatically, without receiving notifications for
 * unrelated contexts.
 */
static void * const PROManagedObjectContextObserverKey = "PROManagedObjectContextObserver";

@interface PROCoreDataManager () {
    /**
     * Predicate for `dispatch_once()` to make sure the
     * <persistentStoreCoordinator> is created only once.
     */
    dispatch_once_t m_persistentStoreCoordinatorPredicate;

    /**
     * Predicate for `dispatch_once()` to make sure the
     * <managedObjectModel> is created only once.
     */
    dispatch_once_t m_managedObjectModelPredicate;

    /**
     * Predicate for `dispatch_once()` to make sure the
     * <globalContext> is created only once.
     */
    dispatch_once_t m_globalContextPredicate;

    /**
     * Predicate for `dispatch_once()` to make sure the
     * <mainThreadContext> is created only once.
     */
    dispatch_once_t m_mainThreadContextPredicate;
}

/**
 * Invoked when an `NSManagedObjectContext` created by the receiver has
 * completed a save.
 *
 * This is used to update the <mainThreadContext>.
 */
- (void)managedObjectContextDidSave:(NSNotification *)notification;

@end

@implementation PROCoreDataManager

#pragma mark Properties

@synthesize persistentStoreCoordinator = m_persistentStoreCoordinator;
@synthesize managedObjectModel = m_managedObjectModel;
@synthesize globalContext = m_globalContext;
@synthesize mainThreadContext = m_mainThreadContext;

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    dispatch_once(&m_persistentStoreCoordinatorPredicate, ^{
        m_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    });

    return m_persistentStoreCoordinator;
}

- (NSManagedObjectModel *)managedObjectModel {
    dispatch_once(&m_managedObjectModelPredicate, ^{
        m_managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    });

    return m_managedObjectModel;
}

- (NSManagedObjectContext *)globalContext {
    dispatch_once(&m_globalContextPredicate, ^{
        m_globalContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        m_globalContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
        m_globalContext.undoManager = nil;

        __weak PROCoreDataManager *weakSelf = self;

        id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSManagedObjectContextDidSaveNotification
            object:m_globalContext
            queue:nil
            usingBlock:^(NSNotification *notification){
                [weakSelf managedObjectContextDidSave:notification];
            }
        ];

        objc_setAssociatedObject(m_globalContext, PROManagedObjectContextObserverKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });

    return m_globalContext;
}

- (NSManagedObjectContext *)mainThreadContext {
    dispatch_once(&m_mainThreadContextPredicate, ^{
        m_mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        m_mainThreadContext.parentContext = self.globalContext;
        m_mainThreadContext.undoManager = nil;
    });

    return m_mainThreadContext;
}

#pragma mark Managed Object Contexts

- (NSManagedObjectContext *)newContext; {
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    context.parentContext = self.globalContext;
    context.undoManager = nil;

    __weak PROCoreDataManager *weakSelf = self;

    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSManagedObjectContextDidSaveNotification
        object:context
        queue:nil
        usingBlock:^(NSNotification *notification){
            [weakSelf managedObjectContextDidSave:notification];
        }
    ];

    objc_setAssociatedObject(context, PROManagedObjectContextObserverKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return context;
}

- (void)managedObjectContextDidSave:(NSNotification *)notification; {
    [self.mainThreadContext performBlock:^{
        // make sure not to add the merged changes to any undo
        // manager which may exist
        [self.mainThreadContext processPendingChanges];
        [self.mainThreadContext.undoManager disableUndoRegistration];
        
        @onExit {
            [self.mainThreadContext processPendingChanges];
            [self.mainThreadContext.undoManager enableUndoRegistration];
        };

        [self.mainThreadContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

@end
