//
//  PRONSUndoManagerAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

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

    describe(@"UndoStackAdditions", ^{
        it(@"should undo nested group without registering redo", ^{
            [undoManager beginUndoGrouping];
            [undoManager endUndoGrouping];

            expect(undoManager.canUndo).toBeTruthy();
            expect(undoManager.canRedo).toBeFalsy();

            [undoManager undoNestedGroupingWithoutRegisteringRedo];

            expect(undoManager.canUndo).toBeFalsy();
            expect(undoManager.canRedo).toBeFalsy();
        });
    });
    
SpecEnd

