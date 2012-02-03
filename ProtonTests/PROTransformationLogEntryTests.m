//
//  PROTransformationLogEntryTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 02.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROTransformationLogEntry.h>

SpecBegin(PROTransformationLogEntry)

    __block void (^verifyCopying)(PROTransformationLogEntry *);
    __block void (^verifyCoding)(PROTransformationLogEntry *);
    
    before(^{
        verifyCopying = ^(PROTransformationLogEntry *entry){
            expect(entry).toConformTo(@protocol(NSCopying));
            expect([entry copy]).toEqual(entry);
        };

        verifyCoding = ^(PROTransformationLogEntry *entry){
            expect(entry).toConformTo(@protocol(NSCoding));

            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:entry];
            expect(encoded).not.toBeNil();

            PROTransformationLogEntry *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
            expect(decoded).toEqual(entry);
        };
    });

    describe(@"root log entry", ^{
        __block PROTransformationLogEntry *entry;

        before(^{
            entry = [[PROTransformationLogEntry alloc] init];
            expect(entry).not.toBeNil();
        });

        it(@"should have a unique identifier", ^{
            expect(entry.uniqueIdentifier).not.toBeNil();

            // UUID should differ from another entry
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] init];
            expect(anotherEntry.uniqueIdentifier).not.toEqual(entry.uniqueIdentifier);
        });

        it(@"should not have a parent log entry", ^{
            expect(entry.parentLogEntry).toBeNil();
        });

        it(@"should not be equal to another root log entry", ^{
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] init];
            expect(entry).not.toEqual(anotherEntry);
        });

        it(@"should support <NSCopying>", ^{
            verifyCopying(entry);
        });

        it(@"should support <NSCoding>", ^{
            verifyCoding(entry);
        });
    });

    describe(@"child log entry", ^{
        __block PROTransformationLogEntry *rootEntry;
        __block PROTransformationLogEntry *entry;

        before(^{
            rootEntry = [[PROTransformationLogEntry alloc] init];

            entry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
            expect(entry).not.toBeNil();
            expect(entry.parentLogEntry).toEqual(rootEntry);
        });

        it(@"should have a unique identifier", ^{
            expect(entry.uniqueIdentifier).not.toBeNil();

            // UUID should differ from another entry
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
            expect(anotherEntry.uniqueIdentifier).not.toEqual(entry.uniqueIdentifier);
        });

        it(@"should not be equal to its parent", ^{
            expect(entry).not.toEqual(entry.parentLogEntry);
        });

        it(@"should not be equal to another log entry", ^{
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
            expect(entry).not.toEqual(anotherEntry);
        });

        it(@"should support <NSCopying>", ^{
            verifyCopying(entry);
        });

        it(@"should support <NSCoding>", ^{
            verifyCoding(entry);
        });

        it(@"should be a descendant of its parent", ^{
            expect([entry isDescendantOfLogEntry:rootEntry]).toBeTruthy();
        });

        it(@"should be a descendant of its root", ^{
            PROTransformationLogEntry *descendantEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:entry];
            expect([descendantEntry isDescendantOfLogEntry:rootEntry]).toBeTruthy();
        });

        it(@"should not be a descendant of another log entry", ^{
            PROTransformationLogEntry *anotherEntry = [[PROTransformationLogEntry alloc] initWithParentLogEntry:rootEntry];
            expect([entry isDescendantOfLogEntry:anotherEntry]).toBeFalsy();
        });
    });

SpecEnd
