//
//  PRONSManagedObjectContextAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>
#import "TestModel.h"

SpecBegin(PRONSManagedObjectContextAdditions)
    
    __block PROCoreDataManager *manager;

    __block NSManagedObjectContext *context;
    __block TestModel *model;
    __block NSString *name;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();
        expect([manager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();

        context = manager.globalContext;
        expect(context.mergePolicy).toEqual(NSErrorMergePolicy);

        model = [TestModel managedObjectWithContext:context];
        expect(model).not.toBeNil();

        model.name = @"foobar";
        expect([context save:NULL]).toBeTruthy();
    });

    describe(@"multiple context changes", ^{
        __block NSManagedObjectContext *otherContext;
        __block TestModel *otherModel;
        __block NSString *otherName;

        before(^{
            otherContext = [[NSManagedObjectContext alloc] init];
            otherContext.persistentStoreCoordinator = manager.persistentStoreCoordinator;

            NSFetchRequest *request = [TestModel fetchRequest];
            NSArray *models = [otherContext executeFetchRequest:request error:NULL];
            expect(models.count).toEqual(1);

            otherModel = [models objectAtIndex:0];
            expect(otherModel).toBeKindOf([TestModel class]);
            expect(otherModel.name).toEqual(model.name);

            otherModel.name = otherName = @"quux";
            expect([otherContext save:NULL]).toBeTruthy();

            model.name = name = @"fizzbuzz";
        });

        after(^{
            expect(context.mergePolicy).toEqual(NSErrorMergePolicy);
        });

        it(@"should save with error merge policy", ^{
            __block NSError *error = nil;
            expect([context saveWithMergePolicy:NSErrorMergePolicy error:&error]).toBeFalsy();
            expect(error).not.toBeNil();
        });

        it(@"should save with store trump merge policy", ^{
            expect([context saveWithMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy error:NULL]).toBeTruthy();
            
            [context refreshObject:model mergeChanges:NO];
            expect(model.name).toEqual(otherName);
        });

        it(@"should save with object trump merge policy", ^{
            expect([context saveWithMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy error:NULL]).toBeTruthy();
            
            [context refreshObject:model mergeChanges:NO];
            expect(model.name).toEqual(name);
        });

        it(@"should save with rollback merge policy", ^{
            expect([context saveWithMergePolicy:NSRollbackMergePolicy error:NULL]).toBeTruthy();
            
            [context refreshObject:model mergeChanges:NO];
            expect(model.name).toEqual(otherName);
        });

        it(@"should save with overwrite merge policy", ^{
            expect([context saveWithMergePolicy:NSOverwriteMergePolicy error:NULL]).toBeTruthy();
            
            [context refreshObject:model mergeChanges:NO];
            expect(model.name).toEqual(name);
        });

        describe(@"refreshing all objects", ^{
            __block TestModel *secondModel;
            __block NSString *secondName;
            
            __block TestModel *secondOtherModel;
            __block NSString *secondOtherName;

            before(^{
                secondOtherModel = [TestModel managedObjectWithContext:otherContext];
                expect(secondOtherModel).not.toBeNil();

                secondOtherModel.name = @"second";
                expect([otherContext save:NULL]).toBeTruthy();
            });

            before(^{
                NSFetchRequest *request = [TestModel fetchRequest];
                request.predicate = [NSPredicate predicateWithFormat:@"self == %@", secondOtherModel];

                NSArray *models = [context executeFetchRequest:request error:NULL];
                expect(models.count).toEqual(1);

                secondModel = [models objectAtIndex:0];
                expect(secondModel).toBeKindOf([TestModel class]);

                expect(secondModel.name).toEqual(secondOtherModel.name);
                secondModel.name = secondName = @"second model";

                secondOtherModel.name = secondOtherName = @"second other model";
                expect([otherContext save:NULL]).toBeTruthy();
            });

            it(@"should merge changes", ^{
                [context refreshAllObjectsMergingChanges:YES];
                
                expect(secondModel.name).toEqual(secondName);
                expect(model.name).toEqual(name);
            });

            it(@"should refresh without merging changes", ^{
                [context refreshAllObjectsMergingChanges:NO];
                
                expect(secondModel.name).toEqual(secondOtherName);
                expect(model.name).toEqual(otherName);
            });
        });
    });

    it(@"should disable undo while performing a block", ^{
        NSUndoManager *undoManager = [[NSUndoManager alloc] init];
        expect(undoManager).not.toBeNil();

        undoManager.groupsByEvent = NO;
        context.undoManager = undoManager;

        [context performBlockWithDisabledUndoAndWait:^{
            [undoManager beginUndoGrouping];

            model.name = @"fuzzbuzz";
            expect([context save:NULL]).toBeTruthy();

            [undoManager endUndoGrouping];
        }];

        expect(model.name).toEqual(@"fuzzbuzz");
        expect(undoManager.canUndo).toBeFalsy();
    });

    it(@"should return a child context", ^{
        NSManagedObjectContext *childContext = [context newChildContext];
        expect(childContext).not.toBeNil();
        expect(childContext.parentContext).toEqual(context);
        expect(childContext.concurrencyType).toEqual(NSConfinementConcurrencyType);
        expect(childContext.undoManager).toBeNil();
    });

    it(@"should return unique child contexts", ^{
        expect([context newChildContext]).not.toEqual([context newChildContext]);
    });

SpecEnd
