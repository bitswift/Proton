//
//  PROCoreDataManager.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROCoreDataManager.h"

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

    return context;
}

@end
