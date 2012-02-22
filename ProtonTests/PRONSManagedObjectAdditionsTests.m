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

    describe(@"property list conversion", ^{
        __block TestModel *model;
        __block TestSubModel *subModel;

        before(^{
            model = [TestModel managedObjectWithContext:manager.mainThreadContext];
            model.name = @"foobar";

            subModel = [TestSubModel managedObjectWithContext:manager.mainThreadContext];
            subModel.age = 0xBEEF;

            model.subModels = [NSSet setWithObject:subModel];

            expect([manager.mainThreadContext save:NULL]).toBeTruthy();
        });

        after(^{
            expect([manager.mainThreadContext save:NULL]).toBeTruthy();
        });

        it(@"should return a property list", ^{
            NSDictionary *propertyList = subModel.propertyListRepresentation;
            expect(propertyList).not.toBeNil();
            expect([[propertyList objectForKey:PROKeyForObject(subModel, age)] intValue]).toEqual(0xBEEF);

            // should not have encoded the to-one relationship
            expect([propertyList objectForKey:PROKeyForObject(subModel, model)]).toBeNil();
        });

        it(@"should encode to-many relationships into a property list", ^{
            NSDictionary *propertyList = model.propertyListRepresentation;
            expect(propertyList).not.toBeNil();
            expect([propertyList objectForKey:PROKeyForObject(model, name)]).toEqual(@"foobar");

            NSArray *subModels = [propertyList objectForKey:PROKeyForObject(model, subModels)];
            expect(subModels).toBeKindOf([NSArray class]);
            
            expect(subModels.count).toEqual(1);
            expect([subModels objectAtIndex:0]).toEqual(subModel.propertyListRepresentation);
        });

        it(@"should instantiate a model given a property list", ^{
            NSDictionary *propertyList = model.propertyListRepresentation;
            expect(propertyList).not.toBeNil();

            TestModel *anotherModel = [[TestModel alloc] initWithPropertyListRepresentation:propertyList insertIntoManagedObjectContext:manager.mainThreadContext];
            expect(anotherModel).not.toBeNil();
            expect(anotherModel.name).toEqual(model.name);
            expect(anotherModel.propertyListRepresentation).toEqual(propertyList);

            // make sure the subModels restored too
            expect(anotherModel.subModels.count).toEqual(1);

            TestSubModel *anotherSubModel = [anotherModel.subModels anyObject];
            expect(anotherSubModel).toBeKindOf([TestSubModel class]);

            NSSet *insertedObjects = [NSSet setWithObjects:anotherModel, anotherSubModel, nil];
            expect(manager.mainThreadContext.insertedObjects).toEqual(insertedObjects);
        });

        it(@"should archive non-property list values", ^{
            NSRange range = NSMakeRange(2, 10);
            NSValue *rangeValue = [NSValue valueWithRange:range];

            model.value = rangeValue;
            expect(NSEqualRanges([model.value rangeValue], range)).toBeTruthy();

            NSDictionary *propertyList = model.propertyListRepresentation;
            expect(propertyList).not.toBeNil();
            expect([propertyList objectForKey:PROKeyForObject(model, value)]).toBeKindOf([NSData class]);

            TestModel *anotherModel = [[TestModel alloc] initWithPropertyListRepresentation:propertyList insertIntoManagedObjectContext:manager.mainThreadContext];
            expect(anotherModel.value).toEqual(rangeValue);
        });

        it(@"should instantiate a model in another context given a property list", ^{
            NSDictionary *propertyList = model.propertyListRepresentation;
            expect(propertyList).not.toBeNil();

            PROCoreDataManager *anotherManager = [[PROCoreDataManager alloc] init];
            expect(anotherManager).not.toBeNil();
            expect([anotherManager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();

            TestModel *anotherModel = [[TestModel alloc] initWithPropertyListRepresentation:propertyList insertIntoManagedObjectContext:anotherManager.mainThreadContext];
            expect(anotherModel).not.toBeNil();
            expect(anotherModel.name).toEqual(model.name);
            expect(anotherModel.propertyListRepresentation).toEqual(propertyList);

            // make sure the subModels restored too
            expect(anotherModel.subModels.count).toEqual(1);

            TestSubModel *anotherSubModel = [anotherModel.subModels anyObject];
            expect(anotherSubModel).toBeKindOf([TestSubModel class]);

            NSSet *insertedObjects = [NSSet setWithObjects:anotherModel, anotherSubModel, nil];
            expect(anotherManager.mainThreadContext.insertedObjects).toEqual(insertedObjects);
            expect(manager.mainThreadContext.insertedObjects.count).toEqual(0);
        });
    });

SpecEnd
