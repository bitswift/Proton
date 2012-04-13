//
//  PRONSUndoManagerAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 25.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>

@interface UndoTestClass : NSObject
@property (nonatomic, assign, readonly) NSInteger changeCount;

- (void)incrementChangeCountWithUndoManager:(NSUndoManager *)undoManager;
- (void)decrementChangeCountWithUndoManager:(NSUndoManager *)undoManager;
@end

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
                return YES;
            }];

            expect(undoManager.undoActionName).toEqual(@"foobar");
        });

        it(@"should override any action name set within the block", ^{
            [undoManager addGroupingWithActionName:@"foobar" usingBlock:^{
                undoManager.actionName = @"fuzzbuzz";
                return YES;
            }];

            expect(undoManager.undoActionName).toEqual(@"foobar");
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

    describe(@"block memory management", ^{
        __block id block;
        __block id objectRetainedInBlock;

        before(^{
            @autoreleasepool {
                objectRetainedInBlock = [NSMutableString stringWithFormat:@"this is a format %i string", 42];

                block = [^{
                    // reference this in the block to retain it
                    [objectRetainedInBlock appendString:@"foo"];
                } copy];
            }

            expect(objectRetainedInBlock).not.toBeNil();
        });

        it(@"should release undo blocks without a target", ^{
            __weak id weakObject = objectRetainedInBlock;

            @autoreleasepool {
                [undoManager addGroupingWithActionName:nil usingBlock:^{
                    [weakManager registerUndoWithBlock:block];
                    return YES;
                }];

                [undoManager removeAllActions];

                block = nil;
                objectRetainedInBlock = nil;
            }

            expect(weakObject).toBeNil();
        });

        describe(@"undo blocks with a target", ^{
            it(@"should be released when removing all actions", ^{
                __weak id weakObject = objectRetainedInBlock;

                @autoreleasepool {
                    [undoManager addGroupingWithActionName:nil usingBlock:^{
                        [weakManager registerUndoWithTarget:weakObject block:block];
                        return YES;
                    }];

                    [undoManager removeAllActions];

                    block = nil;
                    objectRetainedInBlock = nil;
                }

                expect(weakObject).toBeNil();
            });

            it(@"should be released when removing actions for target", ^{
                __weak id weakObject = objectRetainedInBlock;

                @autoreleasepool {
                    [undoManager addGroupingWithActionName:nil usingBlock:^{
                        [weakManager registerUndoWithTarget:weakObject block:block];
                        return YES;
                    }];

                    [undoManager removeAllActionsWithTarget:weakObject];

                    block = nil;
                    objectRetainedInBlock = nil;
                }

                expect(weakObject).toBeNil();
            });
        });

        it(@"should release undo and redo blocks without a target", ^{
            __weak id weakObject = objectRetainedInBlock;

            @autoreleasepool {
                [undoManager addGroupingWithActionName:nil usingBlock:^{
                    [weakManager registerUndoWithBlock:block redoBlock:block];
                    return YES;
                }];

                [undoManager removeAllActions];

                block = nil;
                objectRetainedInBlock = nil;
            }

            expect(weakObject).toBeNil();
        });

        describe(@"undo and redo blocks with a target", ^{
            it(@"should be released when removing all actions", ^{
                __weak id weakObject = objectRetainedInBlock;

                @autoreleasepool {
                    [undoManager addGroupingWithActionName:nil usingBlock:^{
                        [weakManager registerUndoWithTarget:weakObject block:block redoBlock:block];
                        return YES;
                    }];

                    [undoManager removeAllActions];

                    block = nil;
                    objectRetainedInBlock = nil;
                }

                expect(weakObject).toBeNil();
            });

            it(@"should be released when removing actions for target", ^{
                __weak id weakObject = objectRetainedInBlock;

                @autoreleasepool {
                    [undoManager addGroupingWithActionName:nil usingBlock:^{
                        [weakManager registerUndoWithTarget:weakObject block:block redoBlock:block];
                        return YES;
                    }];

                    [undoManager removeAllActionsWithTarget:weakObject];

                    block = nil;
                    objectRetainedInBlock = nil;
                }

                expect(weakObject).toBeNil();
            });
        });
    });

    describe(@"registering undo and redo with block", ^{
        __block NSInteger changeCount;
        __block void (^decrementBlock)(void);
        __block void (^incrementBlock)(void);

        before(^{
            changeCount = 0;

            decrementBlock = [^{
                --changeCount;
            } copy];

            incrementBlock = [^{
                ++changeCount;
            } copy];
        });

        describe(@"without target", ^{
            before(^{
                [undoManager addGroupingWithActionName:nil usingBlock:^{
                    [weakManager registerUndoWithBlock:incrementBlock redoBlock:decrementBlock];
                    return YES;
                }];
            });

            it(@"should be undoable", ^{
                expect(changeCount).toEqual(0);
                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
            });

            it(@"should be redoable", ^{
                [undoManager undo];

                expect(undoManager.canUndo).toBeFalsy();
                expect(undoManager.canRedo).toBeTruthy();

                [undoManager redo];

                expect(changeCount).toEqual(0);
            });

            it(@"should be undoable after redo", ^{
                [undoManager undo];
                [undoManager redo];

                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
            });
        });

        describe(@"with target", ^{
            before(^{
                [undoManager addGroupingWithActionName:nil usingBlock:^{
                    [weakManager registerUndoWithTarget:incrementBlock block:incrementBlock redoBlock:decrementBlock];
                    return YES;
                }];
            });

            it(@"should be undoable", ^{
                expect(changeCount).toEqual(0);
                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
            });

            it(@"should be redoable", ^{
                [undoManager undo];

                expect(undoManager.canUndo).toBeFalsy();
                expect(undoManager.canRedo).toBeTruthy();

                [undoManager redo];

                expect(changeCount).toEqual(0);
            });

            it(@"should be undoable after redo", ^{
                [undoManager undo];
                [undoManager redo];

                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
            });

            it(@"should be removable with target", ^{
                [undoManager removeAllActionsWithTarget:incrementBlock];
                expect(undoManager.canUndo).toBeFalsy();
            });
        });

        describe(@"interoperation with invocations", ^{
            __block UndoTestClass *testObj;

            before(^{
                testObj = [[UndoTestClass alloc] init];
                expect(testObj).not.toBeNil();

                [undoManager addGroupingWithActionName:nil usingBlock:^{
                    [weakManager registerUndoWithTarget:testObj selector:@selector(incrementChangeCountWithUndoManager:) object:weakManager];
                    [weakManager registerUndoWithTarget:incrementBlock block:incrementBlock redoBlock:decrementBlock];
                    return YES;
                }];
            });

            it(@"should be undoable", ^{
                expect(changeCount).toEqual(0);
                expect(testObj.changeCount).toEqual(0);

                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
                expect(testObj.changeCount).toEqual(1);
            });

            it(@"should be redoable", ^{
                [undoManager undo];

                expect(undoManager.canUndo).toBeFalsy();
                expect(undoManager.canRedo).toBeTruthy();

                [undoManager redo];

                expect(changeCount).toEqual(0);
                expect(testObj.changeCount).toEqual(0);
            });

            it(@"should be undoable after redo", ^{
                [undoManager undo];
                [undoManager redo];

                expect(undoManager.canUndo).toBeTruthy();
                expect(undoManager.canRedo).toBeFalsy();

                [undoManager undo];

                expect(changeCount).toEqual(1);
                expect(testObj.changeCount).toEqual(1);
            });
        });
    });

    describe(@"editing additions", ^{
        __block void (^block)(void);
        __block BOOL calledBlock;
        __block BOOL calledUndoWithBlock;

        before(^{
            calledBlock = NO;
            calledUndoWithBlock = NO;

            block = [^{
                calledBlock = YES;

                [weakManager registerUndoWithBlock:^{
                    calledUndoWithBlock = YES;
                }];
            } copy];
        });

        after(^{
            expect(calledBlock).toBeTruthy();
            expect(calledUndoWithBlock).toBeFalsy();

            [undoManager undo];

            expect(calledUndoWithBlock).toBeTruthy();
        });

        it(@"opens an edit grouping", ^{
            BOOL success = [undoManager tryEditGrouping];
            expect(success).toBeTruthy();

            block();

            [undoManager endEditGrouping];
        });

        it(@"overrides names set within an edit grouping block", ^{
            NSString *expectedName = @"foobar";
            BOOL success = [undoManager tryEditGroupingWithActionName:expectedName usingBlock:^{
                block();
                undoManager.actionName = @"fuzzbuzz";
            }];

            expect(success).toBeTruthy();
            expect(undoManager.undoActionName).toEqual(expectedName);
        });

        describe(@"with an open edit grouping", ^{
            before(^{
                BOOL success = [undoManager tryEditGrouping];
                expect(success).toBeTruthy();
            });

            it(@"does not open an edit grouping after one has been opened", ^{
                BOOL nextSuccess = [undoManager tryEditGrouping];
                expect(nextSuccess).toBeFalsy();

                block();

                [undoManager endEditGrouping];

                expect(undoManager.canUndo).toBeTruthy();
            });

            it(@"can open an edit grouping after one has been closed", ^{
                block();
                [undoManager endEditGrouping];

                BOOL succeededTwice = [undoManager tryEditGrouping];
                expect(succeededTwice).toBeTruthy();

                [undoManager endEditGrouping];

                [undoManager undo];
            });
        });

        describe(@"with a block", ^{
            before(^{
                BOOL success = [undoManager tryEditGroupingWithActionName:@"foobar" usingBlock:block];
                expect(success).toBeTruthy();

                expect(undoManager.undoActionName).toEqual(@"foobar");
                expect(calledBlock).toBeTruthy();
            });

            it(@"can call an edit grouping block twice in a row", ^{
                __block BOOL secondBlockCalled = NO;
                __block BOOL calledUndoWithSecondBlock = NO;

                BOOL success = [undoManager tryEditGroupingUsingBlock:^{
                    secondBlockCalled = YES;
                    [weakManager registerUndoWithBlock:^{
                        calledUndoWithSecondBlock = YES;
                    }];
                }];

                expect(success).toBeTruthy();
                expect(secondBlockCalled).toBeTruthy();

                [undoManager undo];
                expect(calledUndoWithSecondBlock).toBeTruthy();
            });
        });
    });

SpecEnd

@implementation UndoTestClass
@synthesize changeCount = m_changeCount;

- (void)incrementChangeCountWithUndoManager:(NSUndoManager *)undoManager; {
    ++m_changeCount;
    [undoManager registerUndoWithTarget:self selector:@selector(decrementChangeCountWithUndoManager:) object:undoManager];
}

- (void)decrementChangeCountWithUndoManager:(NSUndoManager *)undoManager; {
    --m_changeCount;
    [undoManager registerUndoWithTarget:self selector:@selector(incrementChangeCountWithUndoManager:) object:undoManager];
}

@end

