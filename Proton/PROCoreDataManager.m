//
//  PROCoreDataManager.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROCoreDataManager.h"
#import "EXTScope.h"
#import "NSManagedObjectContext+ConvenienceAdditions.h"
#import "PROAssert.h"
#import <objc/runtime.h>

const NSInteger PROCoreDataManagerNonexistentURLError = 1;

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
@synthesize persistentStoreOptions = m_persistentStoreOptions;
@synthesize persistentStoreType = m_persistentStoreType;

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

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    self.persistentStoreOptions = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
        [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
        nil
    ];

    self.persistentStoreType = NSSQLiteStoreType;
    return self;
}

#pragma mark Error Handling

+ (NSString *)errorDomain {
    return @"com.bitswift.Proton.PROCoreDataManager";
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

        @try {
            [self.mainThreadContext mergeChangesFromContextDidSaveNotification:notification];
        } @catch (NSException *exception) {
            PROAssert(NO, @"Caught exception while attempting to merge save notification into main thread context %@ of %@: %@", self.mainThreadContext, self, exception);
        }
    }];
}

#pragma mark Persistent Stores

- (BOOL)readFromURL:(NSURL *)URL error:(NSError **)error; {
    [self.persistentStoreCoordinator lock];
    @onExit {
        [self.persistentStoreCoordinator unlock];
    };

    if ([self.persistentStoreCoordinator persistentStoreForURL:URL])
        return YES;

    if ([URL isFileURL] && ![[NSFileManager defaultManager] fileExistsAtPath:URL.path]) {
        if (error) {
            *error = [NSError
                errorWithDomain:[PROCoreDataManager errorDomain]
                code:PROCoreDataManagerNonexistentURLError
                userInfo:nil
            ];
        }

        return NO;
    }

    NSArray *existingStores = [self.persistentStoreCoordinator.persistentStores copy];
    NSPersistentStore *newStore = [self.persistentStoreCoordinator
        addPersistentStoreWithType:self.persistentStoreType
        configuration:nil
        URL:URL
        options:self.persistentStoreOptions
        error:error
    ];

    if (!newStore)
        return NO;

    @onExit {
        [self.globalContext performBlockAndWait:^{
            [self.globalContext reset];
        }];
    };

    // only remove the existing stores after we've successfully added our new
    // one
    for (NSPersistentStore *existingStore in existingStores) {
        if (![self.persistentStoreCoordinator removePersistentStore:existingStore error:error])
            return NO;
    }

    return YES;
}

- (BOOL)saveAsURL:(NSURL *)URL error:(NSError **)error; {
    {
        [self.persistentStoreCoordinator lock];
        @onExit {
            [self.persistentStoreCoordinator unlock];
        };

        if (![self.persistentStoreCoordinator persistentStoreForURL:URL]) {
            // this may "fail" even if the item didn't exist to begin with, so we
            // can't really honor the result of this method
            [[NSFileManager defaultManager] removeItemAtURL:URL error:nil];

            NSPersistentStore *newStore;

            if (self.persistentStoreCoordinator.persistentStores.count) {
                newStore = [self.persistentStoreCoordinator
                    migratePersistentStore:[self.persistentStoreCoordinator.persistentStores objectAtIndex:0]
                    toURL:URL
                    options:self.persistentStoreOptions
                    withType:self.persistentStoreType
                    error:error
                ];
            } else {
                newStore = [self.persistentStoreCoordinator
                    addPersistentStoreWithType:self.persistentStoreType
                    configuration:nil
                    URL:URL
                    options:self.persistentStoreOptions
                    error:error
                ];
            }

            if (!newStore)
                return NO;
        }
    }

    __block BOOL success = NO;
    __block NSError *strongError = nil;

    [self.globalContext performBlockAndWait:^{
        success = [self.globalContext save:&strongError];
    }];
    
    if (!success && strongError && error) {
        *error = strongError;
    }

    return success;
}

- (BOOL)saveToURL:(NSURL *)URL error:(NSError **)error; {
    [self.persistentStoreCoordinator lock];
    @onExit {
        [self.persistentStoreCoordinator unlock];
    };

    // this will remain 'nil' if the URL being saved already exists as
    // a persistent store
    NSPersistentStore *originalStore = nil;

    if (self.persistentStoreCoordinator.persistentStores.count) {
        if (![self.persistentStoreCoordinator persistentStoreForURL:URL])
            originalStore = [self.persistentStoreCoordinator.persistentStores objectAtIndex:0];
    } else {
        // create an in-memory store, which we'll use to save changes and then
        // migrate back to after saving to URL
        originalStore = [self.persistentStoreCoordinator
            addPersistentStoreWithType:NSInMemoryStoreType
            configuration:nil
            URL:nil
            options:self.persistentStoreOptions
            error:error
        ];

        if (!originalStore)
            return NO;
    }

    {
        __block BOOL success = NO;
        __block NSError *strongError = nil;

        [self.globalContext performBlockAndWait:^{
            success = [self.globalContext save:&strongError];
        }];
        
        if (!success) {
            if (strongError && error)
                *error = strongError;

            return NO;
        }
    }

    if (!originalStore) {
        // if the store is already at the correct URL, we're done
        return YES;
    }

    // this may "fail" even if the item didn't exist to begin with, so we
    // can't really honor the result of this method
    [[NSFileManager defaultManager] removeItemAtURL:URL error:nil];

    // migrate to the new URL
    NSPersistentStore *newStore = [self.persistentStoreCoordinator
        migratePersistentStore:originalStore
        toURL:URL
        options:self.persistentStoreOptions
        withType:self.persistentStoreType
        error:error
    ];

    if (!newStore)
        return NO;

    // recover our original persistent store
    NSPersistentStore *recoveredStore = [self.persistentStoreCoordinator
        migratePersistentStore:newStore
        toURL:originalStore.URL
        options:originalStore.options
        withType:originalStore.type
        error:error
    ];

    return recoveredStore != nil;
}

@end
