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

- (void)testBlockBasedKVO {
    __block BOOL operationCompleted = NO;

    // we can observe the status flags of NSBlockOperation
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        operationCompleted = YES;
    }];

    void (^callbackBlock)(NSDictionary *) = ^(NSDictionary *changes){
        // make sure the change dictionary matches the structure we expect
        STAssertNotNil(changes, @"");
        STAssertNotNil([changes objectForKey:NSKeyValueChangeKindKey], @"");
        STAssertNil([changes objectForKey:NSKeyValueChangeIndexesKey], @"");

        // the change dictionary shouldn't contain any optional keys (since we
        // didn't pass in any options)
        STAssertNil([changes objectForKey:NSKeyValueChangeOldKey], @"");
        STAssertNil([changes objectForKey:NSKeyValueChangeNewKey], @"");
        STAssertNil([changes objectForKey:NSKeyValueChangeIndexesKey], @"");
        
        // this should be not present or NO (because we're not observing with
        // the "prior" option)
        STAssertFalse([[changes objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue], @"");
    };

    // don't check for mutual exclusion between these two, since the operation
    // may change either or both of them multiple times in an unknown order
    __block BOOL observerInvokedForExecuting = NO;
    __block BOOL observerInvokedForFinished = NO;

    [operation addObserverForKeyPath:@"isExecuting" usingBlock:^(NSDictionary *changes){
        callbackBlock(changes);
        observerInvokedForExecuting = YES;
    }];

    [operation addObserverForKeyPath:@"isFinished" usingBlock:^(NSDictionary *changes){
        callbackBlock(changes);
        observerInvokedForFinished = YES;
    }];
    
    // neither observer should've been triggered yet
    STAssertFalse(observerInvokedForExecuting, @"");
    STAssertFalse(observerInvokedForFinished, @"");

    // start the operation and make sure the observer on -isExecuting is
    // triggered
    [operation start];
    STAssertTrue(observerInvokedForExecuting, @"");

    // wait for the operation to finish and make sure the observer on
    // -isFinished is triggered
    [operation waitUntilFinished];

    STAssertTrue(operationCompleted, @"");
    STAssertTrue(observerInvokedForFinished, @"");
}

- (void)testBlockBasedKVOWithOptions {
    __block BOOL operationCompleted = NO;

    // we can observe the status flags of NSBlockOperation
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        operationCompleted = YES;
    }];

    void (^callbackBlock)(NSDictionary *) = ^(NSDictionary *changes){
        // make sure the change dictionary matches the structure we expect
        STAssertNotNil(changes, @"");
        STAssertNotNil([changes objectForKey:NSKeyValueChangeKindKey], @"");
        STAssertNil([changes objectForKey:NSKeyValueChangeIndexesKey], @"");
        
        // this should be not present or NO (because we're not observing with
        // the "prior" option)
        STAssertFalse([[changes objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue], @"");
    };

    // don't check for mutual exclusion between these two, since the operation
    // may change either or both of them multiple times in an unknown order
    __block BOOL observerInvokedForExecuting = NO;
    __block BOOL observerInvokedForFinished = NO;

    [operation addObserverForKeyPath:@"isExecuting" options:NSKeyValueObservingOptionNew usingBlock:^(NSDictionary *changes){
        callbackBlock(changes);

        // the change dictionary should contain the new value (as a boolean
        // NSNumber) and not the old value
        STAssertNil([changes objectForKey:NSKeyValueChangeOldKey], @"");
        STAssertTrue([[changes objectForKey:NSKeyValueChangeNewKey] isKindOfClass:[NSNumber class]], @"");

        observerInvokedForExecuting = YES;
    }];

    [operation addObserverForKeyPath:@"isFinished" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial usingBlock:^(NSDictionary *changes){
        callbackBlock(changes);

        // the change dictionary should not contain the new value
        //
        // we don't check for the old value because using the "initial" option
        // will generate an initial notification with a previous value of nil
        STAssertNil([changes objectForKey:NSKeyValueChangeNewKey], @"");

        observerInvokedForFinished = YES;
    }];

    // the -isFinished observer should've already been triggered, since we asked
    // for an initial observation
    STAssertFalse(observerInvokedForExecuting, @"");
    STAssertTrue(observerInvokedForFinished, @"");

    // reset it to test the actual change below
    observerInvokedForFinished = NO;

    // start the operation and make sure the observer on -isExecuting is
    // triggered
    [operation start];
    STAssertTrue(observerInvokedForExecuting, @"");

    // wait for the operation to finish and make sure the observer on
    // -isFinished is triggered
    [operation waitUntilFinished];

    STAssertTrue(operationCompleted, @"");
    STAssertTrue(observerInvokedForFinished, @"");
}

- (void)testBlockBasedKVORemovingObserver {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];

    id observer = [operation addObserverForKeyPath:@"isExecuting" usingBlock:^(NSDictionary *changes){
        // we'll remove this block before changing the status of the operation
        STFail(@"Observer block should not be called after being removed");
    }];

    // remove the observer immediately
    [operation removeObserver:observer forKeyPath:@"isExecuting"];

    // start the operation and make sure the observer is not triggered
    [operation start];
    [operation waitUntilFinished];
}

- (void)testBlockBasedKVOMemoryManagement {
    __weak id observer = nil;

    @autoreleasepool {
        __autoreleasing NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];

        observer = [operation addObserverForKeyPath:@"isExecuting" usingBlock:^(NSDictionary *changes){}];
        STAssertNotNil(observer, @"");
    }

    // the observer should've been destroyed with the popping of the autorelease
    // pool (since the operation would get destroyed at that time)
    STAssertNil(observer, @"");
}

// test the crazy block-based KVO code on a class that is likely to blow up
- (void)testBlockBasedKVOForClassCluster {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    __block BOOL observerInvoked = NO;

    [dictionary addObserverForKeyPath:@"foobar" usingBlock:^(NSDictionary *changes){
        observerInvoked = YES;
    }];

    STAssertFalse(observerInvoked, @"");

    [dictionary setValue:@"blah" forKey:@"foobar"];
    STAssertTrue(observerInvoked, @"");
}

- (void)testBlockBasedKVOForClassClusterRemovingObserver {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    id observer = [dictionary addObserverForKeyPath:@"foobar" usingBlock:^(NSDictionary *changes){
        // we'll remove this block before changing the dictionary
        STFail(@"Observer block should not be called after being removed");
    }];

    [dictionary removeObserver:observer forKeyPath:@"foobar"];

    // change something and make sure the observer is not triggered
    [dictionary setValue:@"blah" forKey:@"foobar"];
}

@end
