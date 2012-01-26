//
//  PRONSUndoManagerAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

SpecBegin(NSUndoManagerAdditions)

    __block NSUndoManager *undoManager;
    __block __weak NSUndoManager *weakManager;

    before(^{
        undoManager = [[NSUndoManager alloc] init];
        expect(undoManager).not.toBeNil();
        
        weakManager = undoManager;

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

    describe(@"adding grouping using block", ^{
        it(@"should set action name", ^{
            [undoManager addGroupingWithActionName:@"foobar" usingBlock:^{
                expect(weakManager.undoActionName).toEqual(@"foobar");
                return YES;
            }];
        });

        it(@"should create nested group", ^{
            [undoManager addGroupingWithActionName:@"foobar" usingBlock:^{
                expect(weakManager.groupingLevel).toEqual(1);
                return YES;
            }];
        });

        it(@"should add on success", ^{
            [undoManager addGroupingWithActionName:@"foobar" usingBlock:^{
                return YES;
            }];

            expect(undoManager.canUndo).toBeTruthy();
        });

        it(@"should not add on failure", ^{
            [undoManager addGroupingWithActionName:@"foobar" usingBlock:^{
                return NO;
            }];

            expect(undoManager.canUndo).toBeFalsy();
        });
    });

    describe(@"registering undo with block", ^{
        __block void (^block)(void);
        __block BOOL calledBlock;

        before(^{
            calledBlock = NO;

            block = [^{
                calledBlock = YES;
            } copy];
        });

        it(@"should be undoable", ^{
            [undoManager addGroupingWithActionName:nil usingBlock:^{
                [weakManager registerUndoWithBlock:block];
                return YES;
            }];

            [undoManager undo];
            expect(calledBlock).toBeTruthy();
        });

        it(@"should be redoable", ^{
            [undoManager addGroupingWithActionName:nil usingBlock:^{
                [weakManager registerUndoWithBlock:^{
                    [weakManager registerUndoWithBlock:^{
                        block();
                    }];
                }];

                return YES;
            }];

            [undoManager undo];
            expect(calledBlock).toBeFalsy();
            expect(undoManager.canRedo).toBeTruthy();

            [undoManager redo];
            expect(calledBlock).toBeTruthy();
        });
        
        it(@"should be undoable with target", ^{
            [undoManager addGroupingWithActionName:nil usingBlock:^{
                [weakManager registerUndoWithTarget:block block:block];
                return YES;
            }];

            [undoManager undo];
            expect(calledBlock).toBeTruthy();
        });

        it(@"should be removable with target", ^{
            [undoManager addGroupingWithActionName:nil usingBlock:^{
                [weakManager registerUndoWithTarget:block block:block];
                return YES;
            }];

            [undoManager removeAllActionsWithTarget:block];
            expect(undoManager.canUndo).toBeFalsy();
        });
    });
    
SpecEnd

