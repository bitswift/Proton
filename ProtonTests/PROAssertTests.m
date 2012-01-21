//
//  PROAssertTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROAssertTests.h"

// pretend we're in a Release build, so PROAssert() doesn't crash the unit test
#undef DEBUG
#define NDEBUG 1

// TODO: argh, can't import just PROAssert, as it needs DDLog
#import <Proton/Proton.h>

@implementation PROAssertTests

- (void)testTrue {
    if (!PROAssert(YES, @"This assertion should not fail")) {
        STFail(@"PROAssert() with a non-zero condition should return YES");
    }
}

- (void)testFalse {
    // this should log a message to the console
    if (PROAssert(NO, @"Expected failure")) {
        STFail(@"PROAssert() with a zero condition should return NO");
    }
}

@end
