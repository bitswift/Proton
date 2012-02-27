//
//  PROCoreDataManagerTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>
#import "TestModel.h"
#import "TestSubModel.h"

SpecBegin(PROCoreDataManager)

    __block PROCoreDataManager *manager;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();
    });

    after(^{
        // make sure to tear down all the contexts as soon as possible
        manager = nil;
    });

    it(@"should include migration options by default", ^{
        expect([[manager.persistentStoreOptions objectForKey:NSMigratePersistentStoresAutomaticallyOption] boolValue]).toBeTruthy();
        expect([[manager.persistentStoreOptions objectForKey:NSInferMappingModelAutomaticallyOption] boolValue]).toBeTruthy();
    });

    it(@"should use a SQLite store type by default", ^{
        expect(manager.persistentStoreType).toEqual(NSSQLiteStoreType);
    });

    it(@"should load a managed object model automatically", ^{
        NSManagedObjectModel *model = manager.managedObjectModel;
        expect(model).not.toBeNil();

        // this should be the same object
        expect(manager.managedObjectModel == model).toBeTruthy();

        NSArray *entities = model.entitiesByName.allKeys;
        expect(entities).toContain(@"TestModel");
        expect(entities).toContain(@"TestSubModel");
    });

    it(@"should have a persistent store coordinator", ^{
        NSPersistentStoreCoordinator *coordinator = manager.persistentStoreCoordinator;
        expect(coordinator).not.toBeNil();

        // this should be the same object
        expect(manager.persistentStoreCoordinator == coordinator).toBeTruthy();

        expect(coordinator.managedObjectModel).toEqual(manager.managedObjectModel);
    });

    describe(@"in-memory persistent store", ^{
        __block NSEntityDescription *testModelEntity;
        __block NSEntityDescription *testSubModelEntity;

        before(^{
            expect([manager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();

            testModelEntity = [manager.managedObjectModel.entitiesByName objectForKey:@"TestModel"];
            expect(testModelEntity).not.toBeNil();

            testSubModelEntity = [manager.managedObjectModel.entitiesByName objectForKey:@"TestSubModel"];
            expect(testSubModelEntity).not.toBeNil();
        });

        it(@"should have a global context", ^{
            NSManagedObjectContext *context = manager.globalContext;
            expect(context).not.toBeNil();

            // this should be the same object
            expect(manager.globalContext == context).toBeTruthy();

            expect(context.persistentStoreCoordinator).toEqual(manager.persistentStoreCoordinator);
            expect(context.parentContext).toBeNil();
            expect(context.concurrencyType).toEqual(NSPrivateQueueConcurrencyType);
            expect(context.undoManager).toBeNil();
        });

        describe(@"new context", ^{
            __block NSManagedObjectContext *context;

            before(^{
                context = [manager newContext];
                expect(context).not.toBeNil();

                expect(context.parentContext).toEqual(manager.globalContext);
                expect(context.concurrencyType).toEqual(NSConfinementConcurrencyType);
                expect(context.undoManager).toBeNil();
            });

            after(^{
                context = nil;
            });

            it(@"should save to the global context", ^{
                TestModel *model = [[TestModel alloc] initWithEntity:testModelEntity insertIntoManagedObjectContext:context];
                model.name = @"foobar";

                expect([context hasChanges]).toBeTruthy();
                expect([manager.globalContext hasChanges]).toBeFalsy();
                expect([context save:NULL]).toBeTruthy();

                expect([context hasChanges]).toBeFalsy();
                expect([manager.globalContext hasChanges]).toBeTruthy();

                TestModel *globalModel = [manager.globalContext.insertedObjects anyObject];
                expect(globalModel.name).toEqual(@"foobar");
                
                expect([manager.globalContext save:NULL]).toBeTruthy();
                expect([manager.globalContext hasChanges]).toBeFalsy();
            });
        });

        describe(@"main thread context", ^{
            it(@"should have a main thread context", ^{
                NSManagedObjectContext *context = manager.mainThreadContext;
                expect(context).not.toBeNil();

                // this should be the same object
                expect(manager.mainThreadContext == context).toBeTruthy();

                expect(context.parentContext).toEqual(manager.globalContext);
                expect(context.concurrencyType).toEqual(NSMainQueueConcurrencyType);
                expect(context.undoManager).toBeNil();
            });

            it(@"should save to the global context", ^{
                TestModel *model = [[TestModel alloc] initWithEntity:testModelEntity insertIntoManagedObjectContext:manager.mainThreadContext];
                model.name = @"foobar";

                expect([manager.mainThreadContext hasChanges]).toBeTruthy();
                expect([manager.globalContext hasChanges]).toBeFalsy();
                expect([manager.mainThreadContext save:NULL]).toBeTruthy();

                expect([manager.mainThreadContext hasChanges]).toBeFalsy();
                expect([manager.globalContext hasChanges]).toBeTruthy();

                TestModel *globalModel = [manager.globalContext.insertedObjects anyObject];
                expect(globalModel.name).toEqual(@"foobar");
                
                expect([manager.globalContext save:NULL]).toBeTruthy();
                expect([manager.globalContext hasChanges]).toBeFalsy();
            });

            it(@"should merge changes from other contexts", ^{
                TestModel *model = [[TestModel alloc] initWithEntity:testModelEntity insertIntoManagedObjectContext:manager.mainThreadContext];
                model.name = @"foobar";

                expect([manager.mainThreadContext save:NULL]).toBeTruthy();

                NSManagedObjectContext *otherContext = [manager newContext];
                expect(otherContext).not.toBeNil();

                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"TestModel"];
                NSArray *models = [otherContext executeFetchRequest:fetchRequest error:NULL];
                expect(models.count).toEqual(1);

                TestModel *otherModel = [models objectAtIndex:0];
                expect(otherModel.name).toEqual(@"foobar");

                otherModel.name = @"fizzbuzz";
                expect([otherContext save:NULL]).toBeTruthy();

                expect(model.name).toEqual(@"fizzbuzz");
            });

            it(@"should receive changes from the global context", ^{
                TestModel *model = [[TestModel alloc] initWithEntity:testModelEntity insertIntoManagedObjectContext:manager.mainThreadContext];
                model.name = @"foobar";

                expect([manager.mainThreadContext save:NULL]).toBeTruthy();

                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"TestModel"];
                NSArray *models = [manager.globalContext executeFetchRequest:fetchRequest error:NULL];
                expect(models.count).toEqual(1);

                TestModel *otherModel = [models objectAtIndex:0];
                expect(otherModel.name).toEqual(@"foobar");

                otherModel.name = @"fizzbuzz";
                expect([manager.globalContext save:NULL]).toBeTruthy();

                expect(model.name).toEqual(@"foobar");

                [manager.mainThreadContext refreshObject:model mergeChanges:YES];
                expect(model.name).toEqual(@"fizzbuzz");
            });
        });
    });

    describe(@"on-disk persistent store", ^{
        // the different persistent store types to test
        NSArray *storeTypes = [NSArray arrayWithObjects:
            NSSQLiteStoreType,
            NSBinaryStoreType,

            #ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            // this store is not supported on iOS
            NSXMLStoreType,
            #endif

            nil
        ];

        for (NSString *storeType in storeTypes) {
            describe([NSString stringWithFormat:@"%@ store", storeType], ^{
                __block NSURL *storeURL;
                __block NSURL *secondURL;

                __block TestModel *model;
                __block NSString *modelName;
                __block id modelValue;

                __block void (^verifyStoreExistsAtURL)(NSURL *);
                __block void (^verifyFileExistsAtURL)(NSURL *);

                __block void (^refetchModel)(void);

                // creates a test database at 'storeURL' completely separate from
                // 'manager', and changes 'modelValue' to be the value property of
                // the TestModel saved into it
                __block void (^createOtherDatabaseAtStoreURL)(void);

                before(^{
                    manager.persistentStoreType = storeType;
                    expect(manager.persistentStoreType).toEqual(storeType);

                    // set up some non-standard options to test that they get used
                    // correctly
                    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSIgnorePersistentStoreVersioningOption];
                    manager.persistentStoreOptions = options;
                    expect(manager.persistentStoreOptions).toEqual(options);

                    // create an unsaved change in the global context
                    model = [TestModel managedObjectWithContext:manager.globalContext];
                    expect(model).not.toBeNil();

                    model.name = modelName = @"foobar";
                    modelValue = model.value;
                    expect([manager.globalContext hasChanges]).toBeTruthy();

                    // create a temporary path for this database
                    PROUniqueIdentifier *identifier = [[PROUniqueIdentifier alloc] init];
                    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:identifier.stringValue];

                    storeURL = [NSURL fileURLWithPath:temporaryPath isDirectory:NO];
                    expect(storeURL).not.toBeNil();

                    secondURL = [NSURL fileURLWithPath:[temporaryPath stringByAppendingString:@"_second"] isDirectory:NO];
                    expect(secondURL).not.toBeNil();

                    // make sure nothing already exists here
                    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:NULL];
                    [[NSFileManager defaultManager] removeItemAtURL:secondURL error:NULL];

                    createOtherDatabaseAtStoreURL = [^{
                        // create a completely separate database to save to 'storeURL'
                        __attribute__((objc_precise_lifetime)) PROCoreDataManager *otherManager = [[PROCoreDataManager alloc] init];
                        expect(otherManager).not.toBeNil();

                        otherManager.persistentStoreType = storeType;

                        TestModel *otherModel = [TestModel managedObjectWithContext:otherManager.globalContext];
                        otherModel.value = modelValue = [NSValue valueWithRange:NSMakeRange(1, 48)];

                        expect([otherManager saveAsURL:storeURL error:NULL]).toBeTruthy();
                    } copy];

                    refetchModel = [^{
                        NSFetchRequest *fetchRequest = [TestModel fetchRequest];
                        NSArray *models = [manager.globalContext executeFetchRequest:fetchRequest error:NULL];

                        expect(models).not.toBeNil();
                        expect(models.count).toEqual(1);

                        model = [models objectAtIndex:0];
                    } copy];
                });

                after(^{
                    verifyFileExistsAtURL = [^(NSURL *url){
                        NSString *path = url.path;
                        
                        __block BOOL isDirectory = NO;
                        expect([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]).toBeTruthy();
                        expect(isDirectory).toBeFalsy();
                    } copy];

                    verifyStoreExistsAtURL = [^(NSURL *url){
                        expect(manager.persistentStoreCoordinator.persistentStores.count).toEqual(1);

                        // verify that the persistent store was set up as we
                        // specified
                        NSPersistentStore *store = manager.persistentStoreCoordinator.persistentStores.lastObject;
                        expect(store.type).toEqual(storeType);
                        expect(store.URL).toEqual(url);

                        // Core Data apparently adds some private options to
                        // this dictionary sometimes, so just verify that
                        // everything we requested is in there (not necessarily
                        // that they're equal)
                        [manager.persistentStoreOptions enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop){
                            expect([store.options objectForKey:key]).toEqual(value);
                        }];

                        // make sure it actually exists on disk too
                        verifyFileExistsAtURL(url);
                    } copy];

                    manager = nil;

                    // throw away any test database(s) we created
                    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:NULL];
                    [[NSFileManager defaultManager] removeItemAtURL:secondURL error:NULL];
                });

                it(@"should fail to read a non-existent store", ^{
                    __block NSError *error = nil;
                    expect([manager readFromURL:storeURL error:&error]).toBeFalsy();

                    expect(error.domain).toEqual([PROCoreDataManager errorDomain]);
                    expect(error.code).toEqual(PROCoreDataManagerNonexistentURLError);

                    expect(manager.persistentStoreCoordinator.persistentStores.count).toEqual(0);
                });

                it(@"should 'save as' with a new URL", ^{
                    __block NSError *error = nil;
                    expect([manager saveAsURL:storeURL error:&error]).toBeTruthy();
                    expect(error).toBeNil();

                    expect(manager.globalContext.hasChanges).toBeFalsy();
                    expect(model.name).toEqual(modelName);

                    verifyStoreExistsAtURL(storeURL);
                });

                it(@"should 'save to' with a new URL", ^{
                    __block NSError *error = nil;
                    expect([manager saveToURL:storeURL error:&error]).toBeTruthy();
                    expect(error).toBeNil();

                    expect(manager.globalContext.hasChanges).toBeTruthy();
                    expect(model.name).toEqual(modelName);

                    expect(manager.persistentStoreCoordinator.persistentStores.count).toEqual(0);
                    verifyFileExistsAtURL(storeURL);
                });

                describe(@"with an existing store on disk", ^{
                    before(^{
                        createOtherDatabaseAtStoreURL();
                    });
                    
                    it(@"should read from an existing URL", ^{
                        __block NSError *error = nil;
                        expect([manager readFromURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        // the context should've been reset, thus invalidating
                        // our objects
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        refetchModel();
                        expect(model.name).not.toEqual(modelName);
                        expect(model.value).toEqual(modelValue);

                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should overwrite an existing URL with 'save as'", ^{
                        __block NSError *error = nil;
                        expect([manager saveAsURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(model.name).toEqual(modelName);
                        expect(model.value).not.toEqual(modelValue);
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should overwrite an existing URL with 'save to'", ^{
                        __block NSError *error = nil;
                        expect([manager saveToURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(model.name).toEqual(modelName);
                        expect(model.value).not.toEqual(modelValue);
                        expect(manager.globalContext.hasChanges).toBeTruthy();

                        expect(manager.persistentStoreCoordinator.persistentStores.count).toEqual(0);
                        verifyFileExistsAtURL(storeURL);

                        // verify that reading the URL back in doesn't result in any
                        // changes to our objects
                        expect([manager readFromURL:storeURL error:NULL]).toBeTruthy();

                        refetchModel();
                        expect(model.name).toEqual(modelName);
                        expect(model.value).not.toEqual(modelValue);
                        expect(manager.globalContext.hasChanges).toBeFalsy();
                    });
                });

                describe(@"replacing an existing store on the coordinator", ^{
                    __block TestSubModel *subModel;
                    __block int32_t subModelAge;

                    before(^{
                        // create another test object
                        subModel = [TestSubModel managedObjectWithContext:manager.globalContext];
                        expect(subModel).not.toBeNil();

                        // and do an initial save to 'secondURL'
                        expect([manager saveAsURL:secondURL error:NULL]).toBeTruthy();

                        // then make another change that is not yet saved
                        subModel.age = subModelAge = 186;
                        expect([manager.globalContext hasChanges]).toBeTruthy();
                    });

                    it(@"should read from a URL and replace an existing store", ^{
                        // create another database that we can read from
                        createOtherDatabaseAtStoreURL();

                        __block NSError *error = nil;
                        expect([manager readFromURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();
                        
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        refetchModel();
                        expect(model.name).not.toEqual(modelName);
                        expect(model.value).toEqual(modelValue);

                        // reading from 'storeURL' should've invalidated our
                        // subModel object
                        for (NSManagedObject *object in manager.globalContext.registeredObjects) {
                            expect(object).not.toBeKindOf([TestSubModel class]);
                        }

                        // the persistent store on the coordinator should now be at
                        // 'storeURL', not 'secondURL'
                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should 'save as' with a URL and migrate an existing store", ^{
                        __block NSError *error = nil;
                        expect([manager saveAsURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(subModel.age).toEqual(subModelAge);
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        // the persistent store on the coordinator should now be at
                        // 'storeURL', not 'secondURL'
                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should 'save to' with a URL and not modify an existing store", ^{
                        __block NSError *error = nil;
                        expect([manager saveToURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(subModel.age).toEqual(subModelAge);
                        expect(manager.globalContext.hasChanges).toBeTruthy();

                        // the persistent store on the coordinator should still be at
                        // 'secondURL', but 'storeURL' should also exist on disk
                        verifyStoreExistsAtURL(secondURL);
                        verifyFileExistsAtURL(storeURL);
                    });
                });

                describe(@"updating an existing store on the coordinator", ^{
                    before(^{
                        // do an initial save to 'storeURL'
                        expect([manager saveAsURL:storeURL error:NULL]).toBeTruthy();

                        // then make another change that is not yet saved
                        model.name = modelName = @"fizzbuzz";
                        expect([manager.globalContext hasChanges]).toBeTruthy();
                    });

                    it(@"should not do anything when reading from existing store URL", ^{
                        __block NSError *error = nil;
                        expect([manager readFromURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(model.name).toEqual(modelName);
                        expect(manager.globalContext.hasChanges).toBeTruthy();

                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should 'save as' with existing store URL", ^{
                        __block NSError *error = nil;
                        expect([manager saveAsURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(model.name).toEqual(modelName);
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        verifyStoreExistsAtURL(storeURL);
                    });

                    it(@"should 'save to' with existing store URL", ^{
                        __block NSError *error = nil;
                        expect([manager saveToURL:storeURL error:&error]).toBeTruthy();
                        expect(error).toBeNil();

                        expect(model.name).toEqual(modelName);
                        expect(manager.globalContext.hasChanges).toBeFalsy();

                        verifyStoreExistsAtURL(storeURL);
                    });
                });
            });
        }
    });

SpecEnd
