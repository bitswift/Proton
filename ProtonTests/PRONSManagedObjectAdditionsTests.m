//
//  PRONSManagedObjectAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 20.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>
#import "TestModel.h"
#import "TestSubModel.h"

SpecBegin(PRONSManagedObjectAdditions)
    
    __block PROCoreDataManager *manager;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();
        expect([manager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();
    });

    it(@"should create a managed object given a context", ^{
        TestModel *model = [TestModel managedObjectWithContext:manager.mainThreadContext];
        expect(model).toBeKindOf([TestModel class]);

        expect(model.managedObjectContext).toEqual(manager.mainThreadContext);
        expect(manager.mainThreadContext.insertedObjects).toEqual([NSSet setWithObject:model]);
    });

    it(@"should create a fetch request for a managed object class", ^{
        NSFetchRequest *request = [TestModel fetchRequest];
        expect(request.entityName).toEqual(@"TestModel");
    });

SpecEnd
