//
//  PRONSObjectAdditionsTests.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PRONSObjectAdditionsTests.h"
#import <Proton/Proton.h>
#import <libkern/OSAtomic.h>

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

- (void)testAddObserverOwnedByObject {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    // we use __weak to verify that the lifecycle of the observer is correctly
    // tied to 'self' (i.e., it's not immediately deallocated)
    __weak PROKeyValueObserver *observer;

    // also verify that it's not deallocated when an autorelease pool is popped
    @autoreleasepool {
        observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
    }

    STAssertNotNil(observer, @"");

    // verify that the observer was instantiated correctly
    STAssertEquals(observer.target, operation, @"");
    STAssertEqualObjects(observer.keyPath, keyPath, @"");
    STAssertEquals(observer.options, (NSKeyValueObservingOptions)0, @"");
    STAssertEqualObjects(observer.block, block, @"");
}

- (void)testAddObserverOwnedByObjectWithOptions {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    // we use __weak to verify that the lifecycle of the observer is correctly
    // tied to 'self' (i.e., it's not immediately deallocated)
    __weak PROKeyValueObserver *observer;
    
    // also verify that it's not deallocated when an autorelease pool is popped
    @autoreleasepool {
        observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath options:options usingBlock:block];
    }

    STAssertNotNil(observer, @"");

    // verify that the observer was instantiated correctly
    STAssertEquals(observer.target, operation, @"");
    STAssertEqualObjects(observer.keyPath, keyPath, @"");
    STAssertEquals(observer.options, options, @"");
    STAssertEqualObjects(observer.block, block, @"");
}

- (void)testRemoveOwnedObserver {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    __weak PROKeyValueObserver *observer;
    
    // after this autorelease pool, 'observer' should be guaranteed to be deallocated
    @autoreleasepool {
        observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];

        [self removeOwnedObserver:observer];
    }

    STAssertNil(observer, @"");
}

- (void)testRemoveOwnedObservers {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    __weak PROKeyValueObserver *observer1;
    __weak PROKeyValueObserver *observer2;

    // after this autorelease pool, both observers should be guaranteed to be deallocated
    @autoreleasepool {
        observer1 = [operation addObserverOwnedByObject:self forKeyPath:@"isExecuting" usingBlock:block];
        observer2 = [operation addObserverOwnedByObject:self forKeyPath:@"isFinished" usingBlock:block];

        [self removeAllOwnedObservers];
    }

    STAssertNil(observer1, @"");
    STAssertNil(observer2, @"");
}

- (void)testMultithreadedAddition {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    // the number of observers to test concurrently
    const size_t count = 10;

    __weak PROKeyValueObserver * volatile *observers = (__weak id *)malloc(sizeof(*observers) * count);
    @onExit {
        free((void *)observers);
    };

    dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
        // each thread has its own autorelease pool -- verify that it does not
        // destroy the observer created on this thread
        @autoreleasepool {
            observers[index] = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
        }
    });

    // make sure all stores complete
    OSMemoryBarrier();

    // verify that each observer was instantiated correctly and is still alive
    for (size_t i = 0;i < count;++i) {
        __weak PROKeyValueObserver *observer = observers[i];

        STAssertNotNil(observer, @"");

        STAssertEquals(observer.target, operation, @"");
        STAssertEqualObjects(observer.keyPath, keyPath, @"");
        STAssertEquals(observer.options, (NSKeyValueObservingOptions)0, @"");
        STAssertEqualObjects(observer.block, block, @"");
    }
}

- (void)testMultithreadedRemoval {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
    NSString *keyPath = @"isExecuting";

    PROKeyValueObserverBlock block = [^(NSDictionary *changes){
        // we'll remove this block before changing the status of the operation
        STFail(@"Observer block should not be called after being removed");
    } copy];

    // the number of observers to test concurrently
    const size_t count = 10;

    __weak PROKeyValueObserver * volatile *observers = (__weak id *)malloc(sizeof(*observers) * count);
    @onExit {
        free((void *)observers);
    };

    dispatch_group_t group = dispatch_group_create();
    @onExit {
        dispatch_release(group);
    };

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply(count, queue, ^(size_t index){
        @autoreleasepool {
            observers[index] = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
        }

        dispatch_group_async(group, queue, ^{
            // make sure the store to this index completes before trying to
            // remove it
            OSMemoryBarrier();
            
            @autoreleasepool {
                [self removeOwnedObserver:observers[index]];
            }
        });
    });

    // wait for all removals to complete as well
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    // make sure all stores and weak reference updates complete
    OSMemoryBarrier();

    // verify that each observer was removed correctly and niled out
    for (size_t i = 0;i < count;++i) {
        STAssertNil(observers[i], @"");
    }
    
    // start the operation and make sure no observers are triggered
    [operation start];
    [operation waitUntilFinished];
}

@end
