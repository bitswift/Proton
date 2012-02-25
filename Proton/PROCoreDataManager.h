//
//  PROCoreDataManager.h
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 * An error code when returned when <[PROCoreDataManager readFromURL:error:]> is
 * given a URL that does not already exist.
 */
extern const NSInteger PROCoreDataManagerNonexistentURLError;

/**
 * Manages the state for a single Core Data database.
 */
@interface PROCoreDataManager : NSObject

/**
 * @name Error Handling
 */

/**
 * The error domain for `NSError` objects created by this class.
 */
+ (NSString *)errorDomain;

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
 * a result, saving this managed object context will simply save to the global
 * context, instead of saving directly to the persistent store.
 *
 * This context will _not_ have an `undoManager` by default.
 */
- (NSManagedObjectContext *)newContext;

/**
 * @name Managing the Persistent Store
 */

/**
 * Options to use when creating a persistent store for the receiver.
 *
 * This dictionary should match the format of the `options` dictionary passed to
 * `-[NSPersistentStoreCoordinator
 * addPersistentStoreWithType:configuration:URL:options:error:`.
 *
 * Changes to this property will only be reflected in subsequent calls to
 * <readFromURL:error:>, <saveAsURL:error:>, or <saveToURL:error:> that result
 * in an `NSPersistentStore` being added to the receiver's
 * <persistentStoreCoordinator>. Setting this property will not affect any
 * existing persistent stores.
 *
 * The default value for this property enables
 * `NSMigratePersistentStoresAutomaticallyOption` and
 * `NSInferMappingModelAutomaticallyOption`, to automatically migrate models in
 * opened persistent stores.
 */
@property (copy) NSDictionary *persistentStoreOptions;

/**
 * The type of persistent store to use when automatically creating one for the
 * receiver.
 *
 * Changes to this property will only be reflected in subsequent calls to
 * <readFromURL:error:>, <saveAsURL:error:>, or <saveToURL:error:> that result
 * in an `NSPersistentStore` being added to the receiver's
 * <persistentStoreCoordinator>. Setting this property will not affect any
 * existing persistent stores.
 *
 * The default value for this property is `NSSQLiteStoreType`.
 */
@property (copy) NSString *persistentStoreType;

/**
 * Reads a persistent store from the given URL, adding it to the receiver's
 * <persistentStoreCoordinator>, and resets the <globalContext>. Returns whether
 * the read was successful.
 *
 * If the <persistentStoreCoordinator> already has a persistent store at the
 * given URL, nothing happens, and `YES` is returned. If nothing exists at the
 * given URL, `NO` is returned, and `error` is set to
 * `PROCoreDataManagerNonexistentURLError`. Otherwise, a persistent store of
 * <persistentStoreType> is added with <persistentStoreOptions>, discarding any
 * persistent stores that already exist on the persistent store coordinator.
 *
 * This method is thread-safe.
 *
 * @param URL The URL from which to read a persistent store.
 * @param error If not `NULL`, and this method returns `NO`, this may be filled
 * in with detailed information about the error that occurred.
 */
- (BOOL)readFromURL:(NSURL *)URL error:(NSError **)error;

/**
 * Creates a persistent store at the given URL if necessary, and then saves the
 * <globalContext>. Returns whether the operation was successful.
 *
 * If the <persistentStoreCoordinator> does not already have a persistent store
 * at the given URL, one of two things will occur:
 *
 *  1. If the persistent store coordinator does not currently have any
 *  persistent stores, a persistent store of <persistentStoreType> is added with
 *  <persistentStoreOptions>.
 *  2. If the persistent store coordinator already has one or more persistent
 *  stores, the first object in the `persistentStores` array is migrated to the
 *  given URL with a new type of <persistentStoreType> and using
 *  <persistentStoreOptions>.
 *
 * In either case, once a persistent store exists at the given URL, this method
 * will attempt to save the <globalContext>.
 *
 * This method is thread-safe.
 *
 * @param URL The URL to which the receiver should be saved.
 * @param error If not `NULL`, and this method returns `NO`, this may be filled
 * in with detailed information about the error that occurred.
 */
- (BOOL)saveAsURL:(NSURL *)URL error:(NSError **)error;

/**
 * Saves the current contents of the <globalContext> to the given URL. Returns
 * whether the save was successful.
 *
 * If the <persistentStoreCoordinator> already has a persistent store at the
 * given URL, this method behaves like <saveAsURL:error:>. Otherwise, a new
 * persistent store of <persistentStoreType> will be created at the given URL
 * with <persistentStoreOptions>, and the database, as represented by the
 * current state of the <globalContext>, will be saved to the new URL.
 *
 * When this method returns, the persistent store coordinator will have the same
 * persistent stores as when the method was initially invoked.
 *
 * This method is thread-safe.
 *
 * @param URL The URL to which the <globalContext> should be saved.
 * @param error If not `NULL`, and this method returns `NO`, this may be filled
 * in with detailed information about the error that occurred.
 *
 * @warning **Important:** This method may save the <globalContext> to the
 * current persistent store(s) as part of its implementation.
 */
- (BOOL)saveToURL:(NSURL *)URL error:(NSError **)error;

@end
