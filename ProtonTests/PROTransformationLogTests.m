//
//  PROTransformationLogTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 02.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROMultipleTransformation.h>
#import <Proton/PROTransformationLog.h>
#import <Proton/PROTransformationLogEntry.h>
#import <Proton/PROUniqueTransformation.h>

@interface TestTransformationLogEntry : PROTransformationLogEntry
@end

@interface TestTransformationLog : PROTransformationLog
@end

SpecBegin(PROTransformationLog)
    
    describe(@"base class", ^{
        __block PROTransformationLog *log;

        before(^{
            log = [[PROTransformationLog alloc] init];
            expect(log).not.toBeNil();
        });

        it(@"should have a root log entry", ^{
            expect(log.latestLogEntry).not.toBeNil();
            expect(log.latestLogEntry.parentLogEntry).toBeNil();
        });

        it(@"should initialize with a custom log entry", ^{
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:log.latestLogEntry];

            log = [[PROTransformationLog alloc] initWithLogEntry:anotherEntry];
            expect(log).not.toBeNil();
            expect(log.latestLogEntry).toEqual(anotherEntry);
        });

        it(@"should default to not having an in-memory limit", ^{
            expect(log.maximumNumberOfLogEntries).toEqual(0);
        });

        describe(@"interacting with the log", ^{
            __block PROUniqueTransformation *firstTransformation;
            __block PROUniqueTransformation *secondTransformation;

            __block PROTransformationLogEntry *rootEntry;

            before(^{
                firstTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:@"bar"];
                secondTransformation = [[PROUniqueTransformation alloc] initWithInputValue:@"fizz" outputValue:@"buzz"];

                rootEntry = log.latestLogEntry;
            });

            it(@"should return an empty multiple transformation without any log entries", ^{
                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:rootEntry];

                expect(transformation).not.toBeNil();
                expect(transformation.transformations).toEqual([NSArray array]);
            });

            it(@"should have a new log entry after appending", ^{
                [log appendTransformation:firstTransformation];

                expect(log.latestLogEntry).not.toEqual(rootEntry);
                expect(log.latestLogEntry.parentLogEntry).toEqual(rootEntry);
            });

            it(@"should have distinct log entries with multiple appends", ^{
                [log appendTransformation:firstTransformation];

                PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                [log appendTransformation:secondTransformation];

                expect(log.latestLogEntry).not.toEqual(rootEntry);
                expect(log.latestLogEntry).not.toEqual(middleEntry);
                expect(log.latestLogEntry.parentLogEntry).toEqual(middleEntry);
            });

            it(@"should return a multiple transformation of all log entries", ^{
                [log appendTransformation:firstTransformation];
                [log appendTransformation:secondTransformation];

                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry];
                expect(transformation).not.toBeNil();

                NSArray *expectedTransformations = [NSArray arrayWithObjects:firstTransformation, secondTransformation, nil];
                expect(transformation.transformations).toEqual(expectedTransformations);
            });

            it(@"should return a multiple transformation from part of the log", ^{
                [log appendTransformation:firstTransformation];

                PROTransformationLogEntry *fromEntry = log.latestLogEntry;

                [log appendTransformation:secondTransformation];
                [log appendTransformation:secondTransformation];

                PROTransformationLogEntry *toEntry = log.latestLogEntry;

                [log appendTransformation:firstTransformation];

                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:fromEntry toLogEntry:toEntry];
                expect(transformation).not.toBeNil();

                NSArray *expectedTransformations = [NSArray arrayWithObjects:secondTransformation, secondTransformation, nil];
                expect(transformation.transformations).toEqual(expectedTransformations);
            });

            it(@"should remove a log entry in the log", ^{
                [log appendTransformation:firstTransformation];

                PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                [log appendTransformation:secondTransformation];
                [log removeLogEntry:middleEntry];

                expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry]).toBeNil();
            });

            it(@"should remove all log entries", ^{
                [log appendTransformation:firstTransformation];
                [log appendTransformation:secondTransformation];
                [log removeAllLogEntries];

                // should not have destroyed the latestLogEntry
                expect(log.latestLogEntry).not.toBeNil();
                expect([log multipleTransformationFromLogEntry:log.latestLogEntry toLogEntry:log.latestLogEntry]).not.toBeNil();

                expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry]).toBeNil();
            });

            it(@"should not do anything to remove a log entry not in the log", ^{
                PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
                [log removeLogEntry:anotherEntry];

                expect(log.latestLogEntry).toEqual(rootEntry);

                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:rootEntry];
                expect(transformation).not.toBeNil();
                expect(transformation.transformations).toEqual([NSArray array]);
            });

            it(@"should append a log entry", ^{
                PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
                [log addOrReplaceLogEntry:anotherEntry];

                expect(log.latestLogEntry).toEqual(anotherEntry);

                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:anotherEntry];
                expect(transformation).not.toBeNil();
                expect(transformation.transformations).toEqual([NSArray array]);
            });

            it(@"should destroy associated data when replacing an existing entry", ^{
                [log appendTransformation:firstTransformation];

                PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                [log appendTransformation:secondTransformation];

                PROTransformationLogEntry *lastEntry = log.latestLogEntry;

                [log addOrReplaceLogEntry:middleEntry];

                expect(log.latestLogEntry).toEqual(middleEntry);

                PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:lastEntry];
                expect(transformation).not.toBeNil();
                expect(transformation.transformations).toEqual([NSArray arrayWithObject:secondTransformation]);
            });

            it(@"should implement <NSCopying>", ^{
                [log appendTransformation:firstTransformation];

                PROTransformationLog *copiedLog = [log copy];
                expect(copiedLog).toEqual(log);

                // modifying the new log should not modify the original
                [copiedLog appendTransformation:secondTransformation];
                expect(copiedLog.latestLogEntry).not.toEqual(log.latestLogEntry);
            });

            it(@"should implement <NSCoding>", ^{
                [log appendTransformation:firstTransformation];
                
                NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:log];
                expect(encoded).not.toBeNil();

                PROTransformationLog *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
                expect(decoded).toEqual(log);
            });

            describe(@"moving in the log", ^{
                __block PROTransformationLogEntry *middleEntry;
                __block PROTransformationLogEntry *lastEntry;

                before(^{
                    [log appendTransformation:firstTransformation];

                    middleEntry = log.latestLogEntry;

                    [log appendTransformation:secondTransformation];

                    lastEntry = log.latestLogEntry;
                });

                it(@"should move to the root of the log", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();
                    expect(log.latestLogEntry).toEqual(rootEntry);
                });

                it(@"should return multiple transformations from other parts of the log after moving", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();

                    PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:middleEntry toLogEntry:lastEntry];
                    expect(transformation).not.toBeNil();
                    expect(transformation.transformations).toEqual([NSArray arrayWithObject:secondTransformation]);
                });

                it(@"should return multiple transformations across different hierarchies of log entries", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();

                    [log appendTransformation:firstTransformation];

                    // this should transform from the other head of the log, up to
                    // the root, and then back down to the latest entry
                    PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:lastEntry toLogEntry:log.latestLogEntry];
                    expect(transformation).not.toBeNil();

                    NSArray *expectedTransformations = [NSArray arrayWithObjects:
                        secondTransformation.reverseTransformation,
                        firstTransformation.reverseTransformation,
                        firstTransformation,
                        nil
                    ];

                    expect(transformation.transformations).toEqual(expectedTransformations);
                });

                it(@"should move to the middle of the log", ^{
                    expect([log moveToLogEntry:middleEntry]).toBeTruthy();
                    expect(log.latestLogEntry).toEqual(middleEntry);
                });

                it(@"should move forward in the log after moving backward", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();
                    expect([log moveToLogEntry:middleEntry]).toBeTruthy();
                    expect(log.latestLogEntry).toEqual(middleEntry);
                });

                it(@"should move to a new root log entry", ^{
                    PROTransformationLogEntry *newRoot = [[PROTransformationLogEntry alloc] init];

                    expect([log moveToLogEntry:newRoot]).toBeTruthy();
                    expect(log.latestLogEntry).toEqual(newRoot);
                });

                it(@"should append new entries relative to the latest log entry", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();

                    [log appendTransformation:firstTransformation];

                    PROTransformationLogEntry *newEntry = log.latestLogEntry;
                    expect(newEntry).not.toEqual(rootEntry);
                    expect(newEntry.parentLogEntry).toEqual(rootEntry);
                });

                it(@"should move across non-linear log entries", ^{
                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();

                    [log appendTransformation:firstTransformation];

                    expect([log moveToLogEntry:lastEntry]).toBeTruthy();
                    expect(log.latestLogEntry).toEqual(lastEntry);
                });

                it(@"should not move to a log entry that is not in the log", ^{
                    PROTransformationLogEntry *newEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:lastEntry];

                    expect([log moveToLogEntry:newEntry]).toBeFalsy();
                    expect(log.latestLogEntry).toEqual(lastEntry);
                });
            });

            describe(@"automatic log trimming", ^{
                before(^{
                    // limit to one entry for testing purposes
                    log.maximumNumberOfLogEntries = 1;
                });

                it(@"should not return a multiple transformation containing a removed log entry", ^{
                    [log appendTransformation:firstTransformation];
                    [log appendTransformation:secondTransformation];

                    expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry]).toBeNil();
                });

                it(@"should not move backward to a removed log entry", ^{
                    [log appendTransformation:firstTransformation];

                    PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                    [log appendTransformation:secondTransformation];

                    expect([log moveToLogEntry:middleEntry]).toBeFalsy();
                });

                it(@"should not move forward to a removed log entry", ^{
                    [log appendTransformation:firstTransformation];

                    PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                    expect([log moveToLogEntry:rootEntry]).toBeTruthy();

                    [log appendTransformation:secondTransformation];

                    expect([log moveToLogEntry:middleEntry]).toBeFalsy();
                });

                it(@"should invoke block before removing a log entry", ^{
                    [log appendTransformation:firstTransformation];

                    PROTransformationLogEntry *middleEntry = log.latestLogEntry;

                    __block BOOL blockInvoked = NO;
                    __weak PROTransformationLog *weakLog = log;

                    log.willRemoveLogEntryBlock = ^(PROTransformationLogEntry *entry){
                        expect(blockInvoked).toBeFalsy();
                        blockInvoked = YES;

                        expect(entry).toEqual(middleEntry);
                        expect(weakLog.latestLogEntry).toEqual(middleEntry);

                        // should be able to pull out a multiple transformation
                        // right now
                        PROMultipleTransformation *transformation = [weakLog multipleTransformationFromLogEntry:rootEntry toLogEntry:middleEntry];
                        expect(transformation).not.toBeNil();
                        expect(transformation.transformations).toEqual([NSArray arrayWithObject:firstTransformation]);
                    };

                    [log appendTransformation:secondTransformation];
                    expect(log.latestLogEntry).not.toEqual(middleEntry);

                    expect(blockInvoked).toBeTruthy();
                });
            });

            describe(@"archived log trimming", ^{
                __block PROTransformationLog *(^archivedLogWithLog)(PROTransformationLog *);

                before(^{
                    // limit to one archived entry for testing purposes
                    log.maximumNumberOfArchivedLogEntries = 1;

                    archivedLogWithLog = ^(PROTransformationLog *log){
                        NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:log];
                        expect(encoded).not.toBeNil();

                        PROTransformationLog *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
                        expect(decoded).not.toBeNil();

                        return decoded;
                    };
                });

                it(@"should return archivable log entries", ^{
                    [log appendTransformation:firstTransformation];
                    
                    expect(log.archivableLogEntries).toEqual([NSOrderedSet orderedSetWithObject:log.latestLogEntry]);
                });

                it(@"should not move backward to a removed log entry after archiving", ^{
                    [log appendTransformation:firstTransformation];
                    [log appendTransformation:secondTransformation];

                    expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry]).not.toBeNil();
                    
                    log = archivedLogWithLog(log);

                    expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry]).toBeNil();
                });

                it(@"should archive to a smaller size with a maximum entry limit", ^{
                    PROTransformationLog *unlimitedLog = [[PROTransformationLog alloc] init];

                    [log appendTransformation:firstTransformation];
                    [log appendTransformation:secondTransformation];

                    [unlimitedLog appendTransformation:firstTransformation];
                    [unlimitedLog appendTransformation:secondTransformation];

                    NSData *limitedData = [NSKeyedArchiver archivedDataWithRootObject:log];
                    NSData *unlimitedData = [NSKeyedArchiver archivedDataWithRootObject:unlimitedLog];

                    expect(limitedData.length).toBeLessThan(unlimitedData.length);
                });

                describe(@"without maximums", ^{
                    __block NSMutableOrderedSet *logEntries;

                    before(^{
                        logEntries = [[NSMutableOrderedSet alloc] init];

                        log.maximumNumberOfLogEntries = 0;
                        log.maximumNumberOfArchivedLogEntries = 0;

                        [logEntries addObject:log.latestLogEntry];

                        for (unsigned i = 0; i < 100; ++i) {
                            [log appendTransformation:firstTransformation];
                            [logEntries addObject:log.latestLogEntry];
                        }
                    });

                    it(@"should not remove in-memory log entries", ^{
                        PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry];

                        expect(transformation).not.toBeNil();
                        expect(transformation.transformations).not.toEqual([NSArray array]);
                    });

                    it(@"should not remove archived log entries", ^{
                        expect(log.archivableLogEntries).toEqual(logEntries);

                        log = archivedLogWithLog(log);                       

                        PROMultipleTransformation *transformation = [log multipleTransformationFromLogEntry:rootEntry toLogEntry:log.latestLogEntry];

                        expect(transformation).not.toBeNil();
                        expect(transformation.transformations).not.toEqual([NSArray array]);
                    });
                });
            });

            it(@"should remove log entries when setting a smaller maximum", ^{
                [log appendTransformation:firstTransformation];
                [log appendTransformation:secondTransformation];

                PROTransformationLogEntry *lastEntry = log.latestLogEntry;
                expect(lastEntry).not.toBeNil();
                expect(lastEntry.parentLogEntry).not.toBeNil();

                log.maximumNumberOfLogEntries = 1;

                expect([log multipleTransformationFromLogEntry:rootEntry toLogEntry:lastEntry]).toBeNil();
            });
        });
    });

    describe(@"custom subclass", ^{
        __block TestTransformationLog *log;

        before(^{
            log = [[TestTransformationLog alloc] init];
            expect(log).not.toBeNil();
        });

        it(@"should use its log entry subclass for the root log entry", ^{
            expect(log.latestLogEntry).toBeKindOf([TestTransformationLogEntry class]);
        });

        it(@"should use its log entry subclass for additional log entries", ^{
            PROTransformation *transformation = [[PROUniqueTransformation alloc] initWithInputValue:@"foo" outputValue:@"bar"];
            [log appendTransformation:transformation];

            expect(log.latestLogEntry.parentLogEntry).not.toBeNil();
            expect(log.latestLogEntry).toBeKindOf([TestTransformationLogEntry class]);
        });
    });

SpecEnd

@implementation TestTransformationLogEntry
@end

@implementation TestTransformationLog
- (PROTransformationLogEntry *)logEntryWithParentLogEntry:(PROTransformationLogEntry *)parent; {
    return [[TestTransformationLogEntry alloc] initWithParentLogEntry:parent];
}
@end
