//
//  PROKeyValueObserverTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROKeyValueObserverTests.h"
#import <Proton/PROKeyValueObserver.h>

@implementation PROKeyValueObserverTests

- (void)testInitialization {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    PROKeyValueObserver *observer = [[PROKeyValueObserver alloc]
        initWithTarget:operation
        keyPath:keyPath
        block:block
    ];

    STAssertNotNil(observer, @"");

    // make sure the properties were set up correctly
    STAssertEquals(observer.target, operation, @"");
    STAssertEqualObjects(observer.keyPath, @"isExecuting", @"");
    STAssertEquals(observer.options, (NSKeyValueObservingOptions)0, @"");
    STAssertEqualObjects(observer.block, block, @"");
}

- (void)testInitializationWithOptions {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    PROKeyValueObserver *observer = [[PROKeyValueObserver alloc]
        initWithTarget:operation
        keyPath:keyPath
        options:options
        block:block
    ];

    STAssertNotNil(observer, @"");

    // make sure the properties were set up correctly
    STAssertEquals(observer.target, operation, @"");
    STAssertEqualObjects(observer.keyPath, @"isExecuting", @"");
    STAssertEquals(observer.options, options, @"");
    STAssertEqualObjects(observer.block, block, @"");
}

- (void)testObservation {
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

    // use '__autoreleasing' to indicate to the compiler that these values are
    // used, and should be autoreleased (normal usage would store these objects
    // into a property)
    __autoreleasing id executingObserver = [[PROKeyValueObserver alloc] initWithTarget:operation keyPath:@"isExecuting" block:^(NSDictionary *changes){
        callbackBlock(changes);
        observerInvokedForExecuting = YES;
    }];

    __autoreleasing id finishedObserver = [[PROKeyValueObserver alloc] initWithTarget:operation keyPath:@"isFinished" block:^(NSDictionary *changes){
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

- (void)testObservationWithOptions {
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

    // use '__autoreleasing' to indicate to the compiler that these values are
    // used, and should be autoreleased (normal usage would store these objects
    // into a property)
    __autoreleasing id executingObserver = [[PROKeyValueObserver alloc] initWithTarget:operation keyPath:@"isExecuting" options:NSKeyValueObservingOptionNew block:^(NSDictionary *changes){
        callbackBlock(changes);

        // the change dictionary should contain the new value (as a boolean
        // NSNumber) and not the old value
        STAssertNil([changes objectForKey:NSKeyValueChangeOldKey], @"");
        STAssertTrue([[changes objectForKey:NSKeyValueChangeNewKey] isKindOfClass:[NSNumber class]], @"");

        observerInvokedForExecuting = YES;
    }];

    __autoreleasing id finishedObserver = [[PROKeyValueObserver alloc] initWithTarget:operation keyPath:@"isFinished" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial block:^(NSDictionary *changes){
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

- (void)testRemovingObserver {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];

    // create and destroy the observer before any change occurs
    @autoreleasepool {
        __autoreleasing id observer = [[PROKeyValueObserver alloc] initWithTarget:operation keyPath:@"isExecuting" block:^(NSDictionary *changes){
            // we'll remove this block before changing the status of the operation
            STFail(@"Observer block should not be called after being removed");
        }];
    }

    // start the operation and make sure the observer is not triggered
    [operation start];
    [operation waitUntilFinished];
}

- (void)testObservationOfClassCluster {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    __block BOOL observerInvoked = NO;

    // use '__autoreleasing' to indicate to the compiler that this value is
    // used, and should be autoreleased (normal usage would store this object
    // into a property)
    __autoreleasing id observer = [[PROKeyValueObserver alloc] initWithTarget:dictionary keyPath:@"foobar" block:^(NSDictionary *changes){
        observerInvoked = YES;
    }];

    STAssertFalse(observerInvoked, @"");

    [dictionary setValue:@"blah" forKey:@"foobar"];
    STAssertTrue(observerInvoked, @"");
}

- (void)testObservationOfClassClusterRemovingObserver {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    // create and destroy the observer before any change occurs
    @autoreleasepool {
        __autoreleasing id observer = [[PROKeyValueObserver alloc] initWithTarget:dictionary keyPath:@"foobar" block:^(NSDictionary *changes){
            // we'll remove this block before changing the dictionary
            STFail(@"Observer block should not be called after being removed");
        }];
    }

    // change something and make sure the observer is not triggered
    [dictionary setValue:@"blah" forKey:@"foobar"];
}

@end
