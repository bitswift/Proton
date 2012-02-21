//
//  PROCoreDataManagerTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROCoreDataManager.h>
#import "TestModel.h"
#import "TestSubModel.h"

SpecBegin(PROCoreDataManager)

    __block PROCoreDataManager *manager;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();
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

    describe(@"with a persistent store", ^{
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
    });

SpecEnd
