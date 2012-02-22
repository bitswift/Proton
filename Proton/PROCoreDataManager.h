//
//  PROCoreDataManager.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * Manages the state for a single Core Data database.
 */
@interface PROCoreDataManager : NSObject

/**
 * @name Database Information
 */

/**
 * The persistent store coordinator for this database.
 *
 * This coordinator is automatically initialized with the receiver's
 * <managedObjectModel> the first time this property is accessed.
 *
 * By default, this coordinator is set up without any persistent stores.
 */
@property (strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/**
 * The managed object model for this database.
 *
 * The default implementation creates a merged managed object model from
 * `+[NSBundle allBundles]` the first time the property is accessed.
 */
@property (strong, readonly) NSManagedObjectModel *managedObjectModel;

/**
 * @name Managed Object Contexts
 */

/**
 * The global managed object context for this database.
 *
 * The default implementation for this property creates a managed object context
 * that uses `NSPrivateQueueConcurrencyType`, and associates it with the
 * <persistentStoreCoordinator>. As a result, saving this managed object context
 * will perform an actual save to the persistent store.
 *
 * There should rarely be a need to use this context directly. Instead, use the
 * <mainThreadContext>, or invoke <newContext> to create a scratch context or
 * a context for a background thread.
 *
 * This context will _not_ have an `undoManager` by default.
 */
@property (strong, readonly) NSManagedObjectContext *globalContext;

/**
 * The managed object context for this database associated with the main thread.
 *
 * The default implementation for this property creates a managed object context
 * that uses `NSMainQueueConcurrencyType`, and associates it with the
 * <globalContext>. As a result, saving this managed object context will simply
 * save to the glboal context, instead of saving directly to the persistent
 * store.
 *
 * This managed object context will automatically merge changes from other
 * managed object contexts that are saved, but only between iterations of the
 * main run loop. This guarantees that managed objects in use on the main thread
 * will not be modified without warning.
 *
 * This context will _not_ have an `undoManager` by default.
 */
@property (strong, readonly) NSManagedObjectContext *mainThreadContext;

/**
 * Creates and returns a confined managed object context for this database.
 *
 * This will create a managed object context that uses
 * `NSConfinementConcurrencyType`, and associate it with the <globalContext>. As
 * a result, saving this manaed object context will simply save to the global
 * context, instead of saving directly to the persistent store.
 *
 * This context will _not_ have an `undoManager` by default.
 */
- (NSManagedObjectContext *)newContext;

@end
