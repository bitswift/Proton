//
//  PRONSUndoManagerAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSUndoManager+RegistrationAdditions.h"
#import "NSUndoManager+UndoStackAdditions.h"

SpecBegin(NSUndoManagerAdditions)

    __block NSUndoManager *undoManager;

    before(^{
        undoManager = [[NSUndoManager alloc] init];
        expect(undoManager).not.toBeNil();

        undoManager.groupsByEvent = NO;
        expect(undoManager.canUndo).toBeFalsy();
        expect(undoManager.canRedo).toBeFalsy();
    });

    it(@"should undo nested group without registering redo", ^{
        [undoManager beginUndoGrouping];
        [undoManager endUndoGrouping];

        expect(undoManager.canUndo).toBeTruthy();
        expect(undoManager.canRedo).toBeFalsy();

        [undoManager undoNestedGroupingWithoutRegisteringRedo];

        expect(undoManager.canUndo).toBeFalsy();
        expect(undoManager.canRedo).toBeFalsy();
    });

    describe(@"registration additions", ^{
        __block NSInteger changeCount;

        __block BOOL (^incrementBlock)(void);
        __block BOOL (^failingIncrementBlock)(void);
        __block void (^decrementBlock)(void);

        before(^{
            changeCount = 0;

            incrementBlock = ^{
                ++changeCount;
                return YES;
            };

            failingIncrementBlock = ^{
                ++changeCount;
                return NO;
            };

            decrementBlock = ^{
                --changeCount;
            };
        });

        it(@"should execute block", ^{
            BOOL success = [undoManager registerGroupWithActionName:nil block:incrementBlock undoBlock:decrementBlock];
            
            expect(success).toBeTruthy();
            expect(changeCount).toEqual(1);
        });

        it(@"should register undo", ^{
            [undoManager registerGroupWithActionName:nil block:incrementBlock undoBlock:decrementBlock];
            expect(undoManager.canUndo).toBeTruthy();

            [undoManager undo];
            expect(changeCount).toEqual(0);
        });

        it(@"should register redo", ^{
            [undoManager registerGroupWithActionName:nil block:incrementBlock undoBlock:decrementBlock];

            [undoManager undo];
            expect(undoManager.canRedo).toBeTruthy();
            
            [undoManager redo];
            expect(changeCount).toEqual(1);
        });

        it(@"should not register undo on failure", ^{
            BOOL success = [undoManager registerGroupWithActionName:nil block:failingIncrementBlock undoBlock:decrementBlock];

            expect(success).toBeFalsy();
            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
            expect(changeCount).toEqual(0);
        });

        it(@"should set action name", ^{
            [undoManager
                registerGroupWithActionName:@"foobar"
                block:^{
                    expect(undoManager.undoActionName).toEqual(@"foobar");
                    return YES;
                }

                undoBlock:^{}
            ];
        });
    });
    
SpecEnd
