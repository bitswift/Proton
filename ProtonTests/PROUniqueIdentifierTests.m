//
//  PROUniqueIdentifierTests.m
//  Proton
//
//  Created by James Lawton on 12/17/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROUniqueIdentifierTests.h"
#import "PROUniqueIdentifier.h"

@implementation PROUniqueIdentifierTests

- (void)testInitialization {
    PROUniqueIdentifier *uid = [[PROUniqueIdentifier alloc] init];
    STAssertNotNil(uid, @"");
}

- (void)testInitializationWithString {
    NSString *uuidString = @"49DDFC35-8DB7-424D-8BD3-1D7FD8508A58";
    PROUniqueIdentifier *uid = [[PROUniqueIdentifier alloc] initWithString:uuidString];

    STAssertEqualObjects(uid.stringValue, uuidString, @"");
}

- (void)testCoding {
    PROUniqueIdentifier *uid = [[PROUniqueIdentifier alloc] init];

    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:uid];
    PROUniqueIdentifier *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];

    STAssertEqualObjects(uid, decoded, @"");
}

- (void)testCopying {
    PROUniqueIdentifier *uid1 = [[PROUniqueIdentifier alloc] init];
    PROUniqueIdentifier *uid2 = [uid1 copy];
    STAssertEqualObjects(uid1, uid2, @"");
}

- (void)testUniqueness {
    PROUniqueIdentifier *uid1 = [[PROUniqueIdentifier alloc] init];
    PROUniqueIdentifier *uid2 = [[PROUniqueIdentifier alloc] init];
    STAssertFalse([uid1 isEqual:uid2], @"");
}

- (void)testStringValue {
    PROUniqueIdentifier *uid1 = [[PROUniqueIdentifier alloc] init];
    NSString *str = [uid1 stringValue];
    STAssertNotNil(str, @"");

    PROUniqueIdentifier *uid2 = [[PROUniqueIdentifier alloc] initWithString:str];
    STAssertEqualObjects(uid1, uid2, @"");
}

- (void)testHash {
    PROUniqueIdentifier *uid = [[PROUniqueIdentifier alloc] init];
    PROUniqueIdentifier *uidFromString = [[PROUniqueIdentifier alloc] initWithString:uid.stringValue];
    STAssertEquals(uid.hash, uidFromString.hash, @"");
}

@end
