//
//  PRONSDictionaryAdditionsTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSDictionaryAdditionsTests.h"
#import <Proton/NSDictionary+PROKeyedObjectAdditions.h>

@implementation PRONSDictionaryAdditionsTests

- (void)testPROKeyedObjectAdditions {
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"bar", @"foo",
        [NSNumber numberWithInt:2], [NSNumber numberWithInt:4],
        [NSNull null], @"null",
        nil
    ];

    STAssertEqualObjects([dict dictionaryValue], dict, @"");
}

@end
