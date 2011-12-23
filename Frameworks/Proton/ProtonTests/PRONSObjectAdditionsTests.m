//
//  PRONSObjectAdditionsTests.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSObjectAdditionsTests.h"
#import <Proton/Proton.h>

@implementation PRONSObjectAdditionsTests

+ (NSString *)errorDomain {
    return @"PRONSObjectAdditionsTestsErrorDomain";
}

- (void)testEquality {
    id obj1 = @"Test1";
    id obj2 = @"Test2";

    STAssertTrueNoThrow(NSEqualObjects(nil, nil), @"");
    STAssertFalseNoThrow(NSEqualObjects(nil, obj1), @"");
    STAssertFalseNoThrow(NSEqualObjects(obj1, nil), @"");
    STAssertTrueNoThrow(NSEqualObjects(obj1, obj1), @"");
    STAssertFalseNoThrow(NSEqualObjects(obj1, obj2), @"");
}

- (void)testErrorGeneration {
    NSInteger errorCode = 1000;
    NSString *errorDescription = @"DESCRIPTION";
    NSString *errorRecoverySuggestion = @"RECOVERY SUGGESTION";
    NSError *error = [self errorWithCode:errorCode description:errorDescription recoverySuggestion:errorRecoverySuggestion];

    STAssertNotNil(error, @"");
    STAssertEquals([error code], errorCode, @"");
    STAssertEqualObjects([error localizedDescription], errorDescription, @"");
    STAssertEqualObjects([error localizedRecoverySuggestion], errorRecoverySuggestion, @"");
    STAssertEqualObjects([error domain], [[self class] errorDomain], @"");
}

@end
