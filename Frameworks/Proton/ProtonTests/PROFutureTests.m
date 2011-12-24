//
//  PROFutureTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROFutureTests.h"
#import <Proton/EXTNil.h>
#import <Proton/PROFuture.h>

@implementation PROFutureTests

- (void)testInitialization {
    PROFuture *future = [PROFuture futureWithBlock:^ id {
        return nil;
    }];

    STAssertNotNil(future, @"");
}

- (void)testForcing {
    NSString *str = @"foobar";

    id obj = [PROFuture futureWithBlock:^{
        return str;
    }];

    [PROFuture resolveFuture:obj];

    STAssertEqualObjects(obj, str, @"");
}

- (void)testForcingNil {
    id obj = [PROFuture futureWithBlock:^ id {
        return nil;
    }];

    [PROFuture resolveFuture:obj];

    STAssertEqualObjects(obj, [EXTNil null], @"");
}

- (void)testImplicitResolution {
    NSString *originalString = @"foobar";

    NSString *str = [PROFuture futureWithBlock:^{
        return originalString;
    }];

    NSString *newString = [str stringByAppendingString:@"buzz"];

    STAssertEqualObjects(str, originalString, @"");
    STAssertEqualObjects(newString, @"foobarbuzz", @"");
}

- (void)testImplicitResolutionOfNil {
    NSString *str = [PROFuture futureWithBlock:^ id {
        return nil;
    }];

    NSString *newString = [str stringByAppendingString:@"buzz"];
    STAssertNil(newString, @"");
}

- (void)testOnlyResolvesOnce {
    __block BOOL resolved = NO;

    NSString *str = [PROFuture futureWithBlock:^{
        STAssertFalse(resolved, @"");
        resolved = YES;

        return @"foobar";
    }];

    [str stringByAppendingString:@"buzz"];

    STAssertTrue(resolved, @"");

    [str stringByAppendingString:@"buzz"];
}

- (void)testOnlyResolvesOnceWithForcing {
    __block BOOL resolved = NO;

    id str = [PROFuture futureWithBlock:^{
        STAssertFalse(resolved, @"");
        resolved = YES;

        return @"foobar";
    }];

    [PROFuture resolveFuture:str];

    STAssertTrue(resolved, @"");

    [PROFuture resolveFuture:str];
}

- (void)testMultithreading {
    NSString *str = [PROFuture futureWithBlock:^{
        return @"thread ";
    }];

    dispatch_apply(10, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
        STAssertEqualObjects(str, @"thread ", @"");

        NSString *threadString = [str stringByAppendingFormat:@"%zu", i];
        NSString *expectedString = [NSString stringWithFormat:@"thread %zu", i];

        STAssertEqualObjects(threadString, expectedString, @"");
    });

    STAssertEqualObjects(str, @"thread ", @"");
}

- (void)testMemoryManagement {
    __weak NSObject *weakObject = nil;

    @autoreleasepool {
        NSObject *object = [[NSObject alloc] init];
        STAssertNotNil(object, @"");

        weakObject = object;

        PROFuture *future = [PROFuture futureWithBlock:^{
            return object;
        }];

        [PROFuture resolveFuture:future];
    }

    // the autorelease pool should've destroyed the future and the object it
    // resolved
    STAssertNil(weakObject, @"");
}

@end
