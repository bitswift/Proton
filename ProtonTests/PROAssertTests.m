//
//  PROAssertTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

// pretend we're in a Release build, so PROAssert() doesn't crash the unit test
#undef DEBUG
#define NDEBUG 1

#import <Proton/PROAssert.h>

SpecBegin(PROAssert)

    it(@"should return YES on a non-zero condition", ^{
        if (!PROAssert(YES, @"This assertion should not fail")) {
            STFail(@"");
        }
    });

    it(@"should return NO on a zero condition", ^{
        // this should log a message to the console
        if (PROAssert(NO, @"Expected failure")) {
            STFail(@"");
        }
    });
    
SpecEnd

