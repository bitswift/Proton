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

    __block NSManagedObjectContext *otherContext;
    __block TestModel *otherModel;
    __block NSString *otherName;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();
        expect([manager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();

        otherContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        otherContext.persistentStoreCoordinator = manager.persistentStoreCoordinator;

        otherModel = [TestModel managedObjectWithContext:otherContext];
        expect(otherModel).not.toBeNil();

        otherModel.name = @"foobar";
        expect([otherContext save:NULL]).toBeTruthy();

        context = manager.globalContext;
        expect(context.mergePolicy).toEqual(NSErrorMergePolicy);
    });

    before(^{
        NSFetchRequest *request = [TestModel fetchRequest];
        NSArray *models = [context executeFetchRequest:request error:NULL];
        expect(models.count).toEqual(1);

        model = [models objectAtIndex:0];
        expect(model).toBeKindOf([TestModel class]);

        expect(model.name).toEqual(otherModel.name);
        model.name = name = @"fizzbuzz";

        otherModel.name = otherName = @"quux";
        expect([otherContext save:NULL]).toBeTruthy();
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

SpecEnd
