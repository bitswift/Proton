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

    describe(@"validating with blocks", ^{
        __block TestModel *model;

        before(^{
            model = [TestModel managedObjectWithContext:manager.mainThreadContext];
            expect(model).not.toBeNil();
        });

        it(@"should validate one block without an error pointer", ^{
            __block BOOL blockInvoked = NO;

            BOOL result = [model validateWithError:NULL usingBlocks:
                ^{
                    blockInvoked = YES;
                    return YES;
                },

                nil
            ];

            expect(result).toBeTruthy();
            expect(blockInvoked).toBeTruthy();
        });

        it(@"should validate one block with an error pointer", ^{
            __block BOOL blockInvoked = NO;

            NSError *error = nil;
            BOOL result = [model validateWithError:&error usingBlocks:
                ^{
                    blockInvoked = YES;
                    return YES;
                },

                nil
            ];

            expect(result).toBeTruthy();
            expect(error).toBeNil();
            expect(blockInvoked).toBeTruthy();
        });

        it(@"should validate two blocks", ^{
            __block BOOL firstBlockInvoked = NO;
            __block BOOL secondBlockInvoked = NO;

            NSError *error = nil;
            BOOL result = [model validateWithError:&error usingBlocks:
                ^{
                    firstBlockInvoked = YES;
                    return YES;
                },

                ^{
                    secondBlockInvoked = YES;
                    return YES;
                },

                nil
            ];

            expect(result).toBeTruthy();
            expect(error).toBeNil();

            expect(firstBlockInvoked).toBeTruthy();
            expect(secondBlockInvoked).toBeTruthy();
        });

        it(@"should fail validation if a block returns NO", ^{
            __block BOOL secondBlockInvoked = NO;

            NSError *error = nil;
            BOOL result = [model validateWithError:&error usingBlocks:
                ^{
                    return NO;
                },

                ^{
                    secondBlockInvoked = YES;
                    return YES;
                },

                nil
            ];

            expect(result).toBeFalsy();
            expect(error).toBeNil();

            // all blocks should've still been invoked
            expect(secondBlockInvoked).toBeTruthy();
        });

        it(@"should set a single error from a failing validation block", ^{
            __autoreleasing NSError *error = nil;
            NSError * __autoreleasing *errorPtr = &error;

            BOOL result = [model validateWithError:errorPtr usingBlocks:
                ^{
                    *errorPtr = [[NSError alloc] initWithDomain:@"foo" code:123 userInfo:nil];
                    return NO;
                },

                ^{
                    return YES;
                },

                nil
            ];

            expect(result).toBeFalsy();
            expect(error).not.toBeNil();

            expect(error.domain).toEqual(@"foo");
            expect(error.code).toEqual(123);
            expect(error.userInfo).toBeNil();
        });

        it(@"should combine multiple errors from failing validation blocks", ^{
            __autoreleasing NSError *error = nil;
            NSError * __autoreleasing *errorPtr = &error;

            BOOL result = [model validateWithError:errorPtr usingBlocks:
                ^{
                    *errorPtr = [[NSError alloc] initWithDomain:@"foo" code:1 userInfo:nil];
                    return NO;
                },

                ^{
                    *errorPtr = [[NSError alloc] initWithDomain:@"foo" code:2 userInfo:nil];
                    return NO;
                },

                nil
            ];

            expect(result).toBeFalsy();
            expect(error).not.toBeNil();

            expect(error.domain).toEqual(NSCocoaErrorDomain);
            expect(error.code).toEqual(NSValidationMultipleErrorsError);

            NSArray *detailedErrors = [error.userInfo objectForKey:NSDetailedErrorsKey];
            expect(detailedErrors).not.toBeNil();
            expect(detailedErrors.count).toEqual(2);

            [detailedErrors enumerateObjectsUsingBlock:^(NSError *error, NSUInteger index, BOOL *stop){
                expect(error.domain).toEqual(@"foo");
                expect(error.code).toEqual(index + 1);
                expect(error.userInfo).toBeNil();
            }];
        });
    });

    describe(@"with an object graph", ^{
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

        describe(@"property list conversion", ^{
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

        describe(@"managed object copying", ^{
            __block PROCoreDataManager *anotherManager;
            
            before(^{
                anotherManager = [[PROCoreDataManager alloc] init];
                expect(anotherManager).not.toBeNil();
                expect([anotherManager.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]).not.toBeNil();
            });

            after(^{
                __block NSError *error = nil;
                expect([anotherManager.mainThreadContext save:&error]).toBeTruthy();
                expect(error).toBeNil();
            });

            it(@"should copy to another managed object context", ^{
                TestModel *copiedModel = [model copyToManagedObjectContext:anotherManager.mainThreadContext];
                expect(copiedModel).not.toBeNil();

                expect([anotherManager.mainThreadContext.insertedObjects containsObject:copiedModel]).toBeTruthy();
                expect(copiedModel.name).toEqual(model.name);
                expect(copiedModel.subModels.count).toEqual(1);

                TestSubModel *copiedSubModel = [copiedModel.subModels anyObject];
                expect([anotherManager.mainThreadContext.insertedObjects containsObject:copiedSubModel]).toBeTruthy();

                expect(copiedSubModel.model).toEqual(copiedModel);
                expect(copiedSubModel.age).toEqual(subModel.age);
            });

            it(@"should copy to another managed object context with specific relationships", ^{
                NSSet *relationships = [NSSet setWithObject:[model.entity.relationshipsByName objectForKey:@"subModels"]];

                TestModel *copiedModel = [model copyToManagedObjectContext:anotherManager.mainThreadContext includingRelationships:relationships];
                expect(copiedModel).not.toBeNil();

                expect([anotherManager.mainThreadContext.insertedObjects containsObject:copiedModel]).toBeTruthy();
                expect(copiedModel.name).toEqual(model.name);
                expect(copiedModel.subModels.count).toEqual(1);

                TestSubModel *copiedSubModel = [copiedModel.subModels anyObject];
                expect([anotherManager.mainThreadContext.insertedObjects containsObject:copiedSubModel]).toBeTruthy();

                expect(copiedSubModel.model).toEqual(copiedModel);
                expect(copiedSubModel.age).toEqual(subModel.age);
            });

            it(@"should copy to another managed object context without relationships", ^{
                TestModel *copiedModel = [model copyToManagedObjectContext:anotherManager.mainThreadContext includingRelationships:nil];
                expect(copiedModel).not.toBeNil();

                expect(anotherManager.mainThreadContext.insertedObjects).toEqual([NSSet setWithObject:copiedModel]);
                expect(copiedModel.name).toEqual(model.name);
                expect(copiedModel.subModels.count).toEqual(0);
            });
        });
    });

SpecEnd
