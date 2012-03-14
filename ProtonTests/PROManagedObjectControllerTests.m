//
//  PROManagedObjectControllerTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>
#import "TestModel.h"

@interface TestEditor : NSObject
@property (nonatomic, assign) BOOL shouldFailToCommit;
@property (nonatomic, copy, readonly) NSError *testError;
@property (nonatomic, weak) PROManagedObjectController *controller;

- (id)initWithController:(PROManagedObjectController *)controller;

- (BOOL)commitEditing;
- (BOOL)commitEditingAndReturnError:(NSError **)error;
- (void)discardEditing;

@property (nonatomic) void *contextInfo;

- (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo;
@end

SpecBegin(PROManagedObjectController)
    
    __block PROCoreDataManager *manager;
    __block NSManagedObjectContext *context;
    __block NSUndoManager *undoManager;

    __block TestModel *model;

    before(^{
        manager = [[PROCoreDataManager alloc] init];
        expect(manager).not.toBeNil();

        context = manager.mainThreadContext;
        expect(context).not.toBeNil();

        undoManager = [[NSUndoManager alloc] init];
        expect(undoManager).not.toBeNil();

        undoManager.groupsByEvent = NO;
        context.undoManager = undoManager;

        [undoManager beginUndoGrouping];

        model = [TestModel managedObjectWithContext:context];
        expect(model).not.toBeNil();

        [undoManager endUndoGrouping];
        
        // immediately remove all actions, so we can test things being added or
        // not added to the undo manager
        [undoManager removeAllActions];

        expect([context save:NULL]).toBeTruthy();
    });

    after(^{
        manager = nil;
    });

    __block PROManagedObjectController *controller;
    __block NSSet *editors;

    before(^{
        controller = [[PROManagedObjectController alloc] initWithModel:model];
        expect(controller).not.toBeNil();

        expect(controller.model).toEqual(model);
        expect(controller.managedObjectContext).toEqual(context);
        expect(controller.undoManager).toEqual(undoManager);
        expect(controller.groupsByEdit).toBeTruthy();
        expect(controller.saveOnCommitEditing).toBeTruthy();
        expect(controller.rollbackOnDiscardEditing).toBeTruthy();
        expect(controller.parentController).toBeNil();
        expect(controller.editing).toBeFalsy();
        expect(controller.currentEditors.count).toEqual(0);

        editors = [NSSet setWithObjects:
            [[TestEditor alloc] initWithController:controller],
            [[TestEditor alloc] initWithController:controller],
            nil
        ];
    });

    after(^{
        controller = nil;
    });

    __block PROKeyValueObserver *editingObserver;
    __block BOOL editingObserverInvoked;

    __block PROKeyValueObserver *currentEditorsObserver;
    __block BOOL currentEditorsObserverInvoked;

    before(^{
        editingObserverInvoked = NO;
        editingObserver = [[PROKeyValueObserver alloc]
            initWithTarget:controller
            keyPath:PROKeyForObject(controller, editing)
            block:^(NSDictionary *changes){
                editingObserverInvoked = YES;
            }
        ];

        currentEditorsObserverInvoked = NO;
        currentEditorsObserver = [[PROKeyValueObserver alloc]
            initWithTarget:controller
            keyPath:PROKeyForObject(controller, currentEditors)
            block:^(NSDictionary *changes){
                currentEditorsObserverInvoked = YES;
            }
        ];
    });

    after(^{
        editingObserver = nil;
        currentEditorsObserver = nil;
    });

    it(@"should begin editing when an object begins editing", ^{
        TestEditor *editor = [editors anyObject];
        [controller objectDidBeginEditing:editor];
        
        expect(controller.currentEditors).toEqual([NSSet setWithObject:editor]);
        expect(controller.editing).toBeTruthy();

        expect(currentEditorsObserverInvoked).toBeTruthy();
        expect(editingObserverInvoked).toBeTruthy();
    });

    it(@"should stay editing when multiple objects begin editing", ^{
        for (TestEditor *editor in editors) {
            [controller objectDidBeginEditing:editor];
            
            expect(controller.currentEditors).toContain(editor);
            expect(controller.editing).toBeTruthy();
        }

        expect(controller.currentEditors).toEqual(editors);
    });

    it(@"should end editing when all objects end editing", ^{
        TestEditor *editor = [editors anyObject];
        [controller objectDidBeginEditing:editor];

        editingObserverInvoked = NO;
        currentEditorsObserverInvoked = NO;

        [controller objectDidEndEditing:editor];

        expect(controller.currentEditors.count).toEqual(0);
        expect(controller.editing).toBeFalsy();

        expect(currentEditorsObserverInvoked).toBeTruthy();
        expect(editingObserverInvoked).toBeTruthy();
    });

    it(@"should not end editing after only one editor ends", ^{
        for (TestEditor *editor in editors) {
            [controller objectDidBeginEditing:editor];
        }

        editingObserverInvoked = NO;
        currentEditorsObserverInvoked = NO;

        TestEditor *editor = [editors anyObject];
        [controller objectDidEndEditing:editor];

        NSMutableSet *remainingEditors = [editors mutableCopy];
        [remainingEditors removeObject:editor];

        expect(controller.currentEditors).toEqual(remainingEditors);
        expect(controller.editing).toBeTruthy();

        expect(currentEditorsObserverInvoked).toBeTruthy();
        expect(editingObserverInvoked).toBeFalsy();
    });

    describe(@"finishing edits", ^{
        __block TestEditor *editor;

        before(^{
            // add all the editors
            for (TestEditor *editor in editors) {
                [controller objectDidBeginEditing:editor];
            }

            editingObserverInvoked = NO;
            currentEditorsObserverInvoked = NO;

            editor = [editors anyObject];
        });

        describe(@"committing changes", ^{
            after(^{
                if (editor.shouldFailToCommit) {
                    expect(controller.currentEditors).toContain(editor);
                    expect(controller.editing).toBeTruthy();
                    expect(editingObserverInvoked).toBeFalsy();
                } else {
                    expect(controller.currentEditors.count).toEqual(0);
                    expect(controller.editing).toBeFalsy();
                    expect(currentEditorsObserverInvoked).toBeTruthy();
                    expect(editingObserverInvoked).toBeTruthy();
                }
            });

            it(@"should commitEditing if all editors commit", ^{
                expect([^{
                    expect([controller commitEditing]).toBeTruthy();
                } copy]).toInvoke(editor, @selector(commitEditingAndReturnError:));
            });

            it(@"should fail to commitEditing if any editor fails", ^{
                editor.shouldFailToCommit = YES;

                expect([^{
                    expect([controller commitEditing]).toBeFalsy();
                } copy]).toInvoke(controller, @selector(handleError:fromEditor:));
            });

            it(@"should commitEditingAndReturnError: if all editors commit", ^{
                expect([^{
                    __block NSError *error = nil;
                    expect([controller commitEditingAndReturnError:&error]).toBeTruthy();
                    expect(error).toBeNil();
                } copy]).toInvoke(editor, @selector(commitEditingAndReturnError:));
            });

            it(@"should commitAllEditingAndReturnError: identically to commitEditingAndReturnError: without a parent", ^{
                expect([^{
                    __block NSError *error = nil;
                    expect([controller commitAllEditingAndReturnError:&error]).toBeTruthy();
                    expect(error).toBeNil();
                } copy]).toInvoke(editor, @selector(commitEditingAndReturnError:));
            });

            it(@"should fail to commitEditingAndReturnError: if any editor fails", ^{
                editor.shouldFailToCommit = YES;

                __block NSError *error = nil;
                expect([controller commitEditingAndReturnError:&error]).toBeFalsy();
                expect(error.domain).toEqual(editor.testError.domain);
                expect(error.code).toEqual(editor.testError.code);
            });

            it(@"should fail to commitAllEditingAndReturnError: identically to commitEditingAndReturnError: without a parent", ^{
                editor.shouldFailToCommit = YES;

                __block NSError *error = nil;
                expect([controller commitAllEditingAndReturnError:&error]).toBeFalsy();
                expect(error.domain).toEqual(editor.testError.domain);
                expect(error.code).toEqual(editor.testError.code);
            });

            describe(@"delegate callback", ^{
                __block SEL didCommitSelector;
                __block void *contextInfo;

                before(^{
                    didCommitSelector = @selector(editor:didCommit:contextInfo:);
                    contextInfo = "foobar";
                });
                
                it(@"should invoke delegate upon successful commit", ^{
                    expect([^{
                        [controller commitEditingWithDelegate:editor didCommitSelector:didCommitSelector contextInfo:contextInfo];
                    } copy]).toInvoke(editor, didCommitSelector);
                });

                it(@"should invoke delegate upon failed commit", ^{
                    editor.shouldFailToCommit = YES;

                    expect([^{
                        expect([^{
                            [controller commitEditingWithDelegate:editor didCommitSelector:didCommitSelector contextInfo:contextInfo];
                        } copy]).toInvoke(controller, @selector(handleError:fromEditor:));
                    } copy]).toInvoke(editor, didCommitSelector);
                });
            });

            describe(@"block callback", ^{
                __block BOOL blockInvoked;
                __block id block;
                
                before(^{
                    blockInvoked = NO;
                    block = [^(BOOL successful, NSError *error){
                        expect(successful).not.toEqual(editor.shouldFailToCommit);
                        
                        if (successful) {
                            expect(error).toBeNil();
                        } else {
                            expect(error.domain).toEqual(editor.testError.domain);
                            expect(error.code).toEqual(editor.testError.code);
                        }

                        blockInvoked = YES;
                    } copy];
                });

                after(^{
                    expect(blockInvoked).toBeTruthy();
                });

                it(@"should invoke block upon successful commit", ^{
                    expect([^{
                        [controller commitEditingAndPerform:block];
                    } copy]).toInvoke(editor, @selector(commitEditingAndReturnError:));
                });

                it(@"should invoke block upon failed commit", ^{
                    editor.shouldFailToCommit = YES;
                    [controller commitEditingAndPerform:block];
                });
            });
        });

        it(@"should stop editing when discarding changes", ^{
            expect([^{
                [controller discardEditing];
            } copy]).toInvoke(editor, @selector(discardEditing));

            expect(controller.currentEditors.count).toEqual(0);
            expect(controller.editing).toBeFalsy();
            expect(currentEditorsObserverInvoked).toBeTruthy();
            expect(editingObserverInvoked).toBeTruthy();
        });
    });

    describe(@"undo grouping", ^{
        before(^{
            expect(undoManager.groupingLevel).toEqual(0);
            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
        });

        after(^{
            expect(controller.editing).toBeFalsy();
        });

        it(@"should group by edit when groupsByEdit is YES", ^{
            controller.editing = YES;
            expect(undoManager.groupingLevel).toEqual(1);

            controller.editing = NO;
            expect(undoManager.groupingLevel).toEqual(0);

            expect(undoManager.canUndo).toBeTruthy();
            expect(undoManager.canRedo).toBeFalsy();
        });

        it(@"should not group by edit when groupsByEdit is NO", ^{
            controller.groupsByEdit = NO;

            controller.editing = YES;
            expect(undoManager.groupingLevel).toEqual(0);

            controller.editing = NO;
            expect(undoManager.groupingLevel).toEqual(0);

            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
        });

        it(@"should discard open edit grouping when discarding edits", ^{
            controller.editing = YES;

            [controller discardEditing];
            expect(undoManager.groupingLevel).toEqual(0);

            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
        });

        it(@"should not do anything when groupsByEdit is NO and discarding an edit", ^{
            controller.groupsByEdit = NO;
            controller.editing = YES;

            [controller discardEditing];
            expect(undoManager.groupingLevel).toEqual(0);

            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
        });

        it(@"should ignore groupsByEdit without an undo manager", ^{
            context.undoManager = undoManager = nil;
            expect(controller.undoManager).toBeNil();

            controller.editing = YES;
            [controller discardEditing];
        });

        it(@"should use the undo action name of the editor", ^{
            TestEditor *editor = [editors anyObject];

            editor.editingUndoActionName = @"foobar";
            expect(editor.editingUndoActionName).toEqual(@"foobar");

            [controller objectDidBeginEditing:editor];
            expect(undoManager.undoActionName).toEqual(editor.editingUndoActionName);

            controller.editing = NO;
        });

        it(@"should use the undo action name of the last editor registered", ^{
            NSMutableString *name = [NSMutableString string];

            [editors enumerateObjectsUsingBlock:^(TestEditor *editor, BOOL *stop){
                [name appendString:@"foo"];

                editor.editingUndoActionName = name;
                expect(editor.editingUndoActionName).toEqual(name);

                [controller objectDidBeginEditing:editor];
            }];

            expect(undoManager.undoActionName).toEqual(name);
            controller.editing = NO;
        });
    });

    describe(@"context changes", ^{
        __block NSString *name;
        
        before(^{
            // create an unsaved change on the model object
            model.name = name = @"foobar";

            // only start editing after our change, so undo doesn't revert it
            controller.editing = YES;
            
            expect(context.hasChanges).toBeTruthy();
        });

        it(@"should save when saveOnCommitEditing is YES", ^{
            expect([controller commitEditing]).toBeTruthy();
            expect(controller.editing).toBeFalsy();

            expect(model.name).toEqual(name);
            expect(context.hasChanges).toBeFalsy();
        });

        it(@"should not save when saveOnCommitEditing is YES", ^{
            controller.saveOnCommitEditing = NO;

            expect([controller commitEditing]).toBeTruthy();
            expect(controller.editing).toBeFalsy();

            expect(model.name).toEqual(name);
            expect(context.hasChanges).toBeTruthy();
        });

        it(@"should rollback when rollbackOnDiscardEditing is YES", ^{
            [controller discardEditing];
            expect(controller.editing).toBeFalsy();

            expect(model.name).not.toEqual(name);
            expect(context.hasChanges).toBeFalsy();
        });

        it(@"should not rollback when rollbackOnDiscardEditing is NO", ^{
            controller.rollbackOnDiscardEditing = NO;

            [controller discardEditing];
            expect(controller.editing).toBeFalsy();

            expect(model.name).toEqual(name);
        });
    });

    describe(@"with a parent controller", ^{
        __block PROManagedObjectController *parentController;

        before(^{
            parentController = [[PROManagedObjectController alloc] initWithModel:model];
            expect(parentController).not.toBeNil();

            controller.parentController = parentController;
        });

        after(^{
            parentController = nil;
        });

        it(@"should notify the parent of editing changes", ^{
            expect([^{
                controller.editing = YES;
            } copy]).toInvoke(parentController, @selector(objectDidBeginEditing:));

            expect(parentController.currentEditors).toEqual([NSSet setWithObject:controller]);
            expect(parentController.editing).toBeTruthy();

            expect([^{
                controller.editing = NO;
            } copy]).toInvoke(parentController, @selector(objectDidEndEditing:));

            expect(parentController.currentEditors.count).toEqual(0);
            expect(parentController.editing).toBeFalsy();
        });

        describe(@"finishing all editing", ^{
            before(^{
                parentController.editing = YES;
            });

            it(@"should commit the parent upon commitAllEditingAndReturnError:", ^{
                expect([^{
                    __block NSError *error = nil;
                    expect([controller commitAllEditingAndReturnError:&error]).toBeTruthy();
                    expect(error).toBeNil();
                } copy]).toInvoke(parentController, @selector(commitEditingAndReturnError:));

                expect(parentController.editing).toBeFalsy();
            });

            it(@"should fail to commit the parent upon commitAllEditingAndReturnError: if any editor fails", ^{
                TestEditor *editor = [editors anyObject];
                editor.shouldFailToCommit = YES;

                [controller objectDidBeginEditing:editor];

                expect([^{
                    __block NSError *error = nil;
                    expect([controller commitAllEditingAndReturnError:&error]).toBeFalsy();
                    expect(error.domain).toEqual(editor.testError.domain);
                    expect(error.code).toEqual(editor.testError.code);
                } copy]).toInvoke(parentController, @selector(commitEditingAndReturnError:));

                expect(parentController.editing).toBeTruthy();
            });

            it(@"should discard the parent's edits upon discardAllEditing", ^{
                expect([^{
                    [controller discardAllEditing];
                } copy]).toInvoke(parentController, @selector(discardEditing));

                expect(parentController.editing).toBeFalsy();
            });
        });
    });

SpecEnd

@implementation TestEditor
@synthesize shouldFailToCommit = m_shouldFailToCommit;
@synthesize controller = m_controller;
@synthesize contextInfo = m_contextInfo;

- (NSError *)testError {
    return [NSError errorWithDomain:@"TestEditor" code:1 userInfo:nil];
}

- (id)initWithController:(PROManagedObjectController *)controller; {
    self = [self init];
    if (!self)
        return nil;

    self.controller = controller;
    return self;
}

- (BOOL)commitEditing; {
    if (self.shouldFailToCommit)
        return NO;

    [self.controller objectDidEndEditing:self];
    return YES;
}

- (BOOL)commitEditingAndReturnError:(NSError **)error; {
    if (self.shouldFailToCommit) {
        if (error) {
            *error = self.testError;
        }

        return NO;
    }

    [self.controller objectDidEndEditing:self];
    return YES;
}

- (void)discardEditing; {
    [self.controller objectDidEndEditing:self];
}

- (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo; {
    expect(editor).toEqual(self.controller);
    expect(didCommit).not.toEqual(self.shouldFailToCommit);
    expect(contextInfo).toEqual(self.contextInfo);
}

@end
