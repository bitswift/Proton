//
//  PROUniqueIdentifierTests.m
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROUniqueIdentifier.h>

SpecBegin(PROUniqueIdentifier)
    
    __block PROUniqueIdentifier *identifier = nil;

    after(^{
        identifier = nil;
    });

    it(@"initializes with a string", ^{
        NSString *uuidString = @"49DDFC35-8DB7-424D-8BD3-1D7FD8508A58";

        identifier = [[PROUniqueIdentifier alloc] initWithString:uuidString];
        expect(identifier).not.toBeNil();
    });

    before(^{
        identifier = [[PROUniqueIdentifier alloc] init];
        expect(identifier).not.toBeNil();
    });

    it(@"implements <NSCoding>", ^{
        expect(identifier).toConformTo(@protocol(NSCoding));

        NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:identifier];
        expect(encoded).not.toBeNil();

        PROUniqueIdentifier *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
        expect(decoded).toEqual(identifier);
    });

    it(@"implements <NSCopying>", ^{
        expect(identifier).toConformTo(@protocol(NSCopying));

        PROUniqueIdentifier *copied = [identifier copy];
        expect(copied).toEqual(identifier);
    });

    it(@"is unique", ^{
        PROUniqueIdentifier *anotherIdentifier = [[PROUniqueIdentifier alloc] init];
        expect(identifier).not.toEqual(anotherIdentifier);
    });

    describe(@"string value", ^{
        __block NSString *stringValue = nil;

        before(^{
            stringValue = identifier.stringValue;
            expect(stringValue).not.toBeNil();
        });

        it(@"results in an equivalent identifier", ^{
            PROUniqueIdentifier *anotherIdentifier = [[PROUniqueIdentifier alloc] initWithString:stringValue];
            expect(anotherIdentifier).toEqual(identifier);
            expect(anotherIdentifier.hash).toEqual(identifier.hash);
        });
    });

SpecEnd
