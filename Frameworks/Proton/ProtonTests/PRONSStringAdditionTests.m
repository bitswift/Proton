//
//  PRONSStringAdditionTests.m
//  Proton
//
//  Created by James Lawton on 12/13/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSStringAdditionTests.h"
#import <Proton/NSString+UniqueIdentifierAdditions.h>

@implementation PRONSStringAdditionTests

- (void)testUUID {
    NSString *uuid1 = [NSString UUID];
    NSString *uuid2 = [NSString UUID];
    STAssertNotNil(uuid1, @"");
    STAssertNotNil(uuid2, @"");

    STAssertFalse([uuid1 isEqual:uuid2], @"");
}

@end
