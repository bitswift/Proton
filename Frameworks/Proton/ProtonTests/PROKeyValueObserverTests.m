//
//  PROKeyValueObserverTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import "PROKeyValueObserverTests.h"
#import <Proton/PROKeyValueObserver.h>
#import <Proton/SDQueue.h>

@interface PROKeyValueObserverTests ()
@property (nonatomic, strong) id observedObject;
@property (nonatomic, strong) PROKeyValueObserver *executingObserver;
@property (nonatomic, strong) PROKeyValueObserver *finishedObserver;
@end

@interface KVOTestObject : NSObject
@property (nonatomic, strong) NSString *foobar;
@end

@implementation PROKeyValueObserverTests
@synthesize observedObject = m_observedObject;
@synthesize executingObserver = m_executingObserver;
@synthesize finishedObserver = m_finishedObserver;

- (void)tearDown {
    // tear down the observers BEFORE the observed object
    self.executingObserver = nil;
    self.finishedObserver = nil;

    self.observedObject = nil;
}

- (void)testInitialization {
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{}];

    NSString *keyPath = @"isExecuting";
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    self.executingObserver = [[PROKeyValueObserver alloc]
        initWithTarget:self.observedObject
        keyPath:keyPath
        block:block
    ];

    STAssertNotNil(self.executingObserver, @"");

    // make sure the properties were set up correctly
    STAssertEquals(self.executingObserver.target, self.observedObject, @"");
    STAssertEqualObjects(self.executingObserver.keyPath, @"isExecuting", @"");
    STAssertEquals(self.executingObserver.options, (NSKeyValueObservingOptions)0, @"");
    STAssertEqualObjects(self.executingObserver.block, block, @"");
    STAssertEqualObjects(self.executingObserver.queue, [SDQueue currentQueue], @"");
}

- (void)testInitializationWithOptions {
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{}];

    NSString *keyPath = @"isExecuting";
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    PROKeyValueObserverBlock block = [^(NSDictionary *changes){} copy];

    self.executingObserver = [[PROKeyValueObserver alloc]
        initWithTarget:self.observedObject
        keyPath:keyPath
        options:options
        block:block
    ];

    STAssertNotNil(self.executingObserver, @"");

    // make sure the properties were set up correctly
    STAssertEquals(self.executingObserver.target, self.observedObject, @"");
    STAssertEqualObjects(self.executingObserver.keyPath, @"isExecuting", @"");
    STAssertEquals(self.executingObserver.options, options, @"");
    STAssertEqualObjects(self.executingObserver.block, block, @"");
    STAssertEqualObjects(self.executingObserver.queue, [SDQueue currentQueue], @"");
}

- (void)testObservation {
    __block BOOL operationCompleted = NO;

    // we can observe the status flags of NSBlockOperation
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{
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

    // don't check for mutual exclusion between these two, since the self.observedObject
    // may change either or both of them multiple times in an unknown order
    __block BOOL observerInvokedForExecuting = NO;
    __block BOOL observerInvokedForFinished = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isExecuting" block:^(NSDictionary *changes){
        callbackBlock(changes);
        observerInvokedForExecuting = YES;
    }];

    self.finishedObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isFinished" block:^(NSDictionary *changes){
        callbackBlock(changes);
        observerInvokedForFinished = YES;
    }];
    
    // neither observer should've been triggered yet
    STAssertFalse(observerInvokedForExecuting, @"");
    STAssertFalse(observerInvokedForFinished, @"");

    // start the self.observedObject and make sure the observer on -isExecuting is
    // triggered
    [self.observedObject start];
    STAssertTrue(observerInvokedForExecuting, @"");

    // wait for the self.observedObject to finish and make sure the observer on
    // -isFinished is triggered
    [self.observedObject waitUntilFinished];

    STAssertTrue(operationCompleted, @"");
    STAssertTrue(observerInvokedForFinished, @"");
}

- (void)testObservationWithOptions {
    __block BOOL operationCompleted = NO;

    // we can observe the status flags of NSBlockOperation
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{
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

    // don't check for mutual exclusion between these two, since the self.observedObject
    // may change either or both of them multiple times in an unknown order
    __block BOOL observerInvokedForExecuting = NO;
    __block BOOL observerInvokedForFinished = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isExecuting" options:NSKeyValueObservingOptionNew block:^(NSDictionary *changes){
        callbackBlock(changes);

        // the change dictionary should contain the new value (as a boolean
        // NSNumber) and not the old value
        STAssertNil([changes objectForKey:NSKeyValueChangeOldKey], @"");
        STAssertTrue([[changes objectForKey:NSKeyValueChangeNewKey] isKindOfClass:[NSNumber class]], @"");

        observerInvokedForExecuting = YES;
    }];

    self.finishedObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isFinished" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial block:^(NSDictionary *changes){
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

    // start the self.observedObject and make sure the observer on -isExecuting is
    // triggered
    [self.observedObject start];
    STAssertTrue(observerInvokedForExecuting, @"");

    // wait for the self.observedObject to finish and make sure the observer on
    // -isFinished is triggered
    [self.observedObject waitUntilFinished];

    STAssertTrue(operationCompleted, @"");
    STAssertTrue(observerInvokedForFinished, @"");
}

- (void)testRemovingObserver {
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{}];

    // create and destroy the observer before any change occurs
    @autoreleasepool {
        self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isExecuting" block:^(NSDictionary *changes){
            // we'll remove this block before changing the status of the self.observedObject
            STFail(@"Observer block should not be called after being removed");
        }];

        self.executingObserver = nil;
    }

    // start the self.observedObject and make sure the observer is not triggered
    [self.observedObject start];
    [self.observedObject waitUntilFinished];
}

- (void)testObservationOfCustomClass {
    self.observedObject = [[KVOTestObject alloc] init];

    __block BOOL observerInvoked = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"foobar" block:^(NSDictionary *changes){
        observerInvoked = YES;
    }];

    STAssertFalse(observerInvoked, @"");

    [self.observedObject setValue:@"blah" forKey:@"foobar"];
    STAssertTrue(observerInvoked, @"");
}

- (void)testObservationOfCustomClassRemovingObserver {
    self.observedObject = [[KVOTestObject alloc] init];

    // create and destroy the observer before any change occurs
    @autoreleasepool {
        self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"foobar" block:^(NSDictionary *changes){
            // we'll remove this block before changing the object
            STFail(@"Observer block should not be called after being removed");
        }];

        self.executingObserver = nil;
    }

    // change something and make sure the observer is not triggered
    [self.observedObject setValue:@"blah" forKey:@"foobar"];
}

- (void)testObservationOfClassCluster {
    self.observedObject = [[NSMutableDictionary alloc] init];

    __block BOOL observerInvoked = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"foobar" block:^(NSDictionary *changes){
        observerInvoked = YES;
    }];

    STAssertFalse(observerInvoked, @"");

    [self.observedObject setValue:@"blah" forKey:@"foobar"];
    STAssertTrue(observerInvoked, @"");
}

- (void)testObservationOfClassClusterRemovingObserver {
    self.observedObject = [[NSMutableDictionary alloc] init];

    // create and destroy the observer before any change occurs
    @autoreleasepool {
        self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"foobar" block:^(NSDictionary *changes){
            // we'll remove this block before changing the object
            STFail(@"Observer block should not be called after being removed");
        }];

        self.executingObserver = nil;
    }

    // change something and make sure the observer is not triggered
    [self.observedObject setValue:@"blah" forKey:@"foobar"];
}

- (void)testBackgroundQueue {
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{}];

    __block BOOL observerInvokedForExecuting = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isExecuting" block:^(NSDictionary *changes){
        observerInvokedForExecuting = YES;
    }];

    SDQueue *queue = [[SDQueue alloc] init];
    self.executingObserver.queue = queue;
    
    STAssertFalse(observerInvokedForExecuting, @"");

    // start the self.observedObject and make sure the observer on -isExecuting is
    // triggered
    [self.observedObject start];

    [queue runSynchronously:^{
        STAssertTrue(observerInvokedForExecuting, @"");
    }];
}

- (void)testNilQueue {
    self.observedObject = [NSBlockOperation blockOperationWithBlock:^{}];

    __block BOOL observerInvokedForExecuting = NO;

    self.executingObserver = [[PROKeyValueObserver alloc] initWithTarget:self.observedObject keyPath:@"isExecuting" block:^(NSDictionary *changes){
        observerInvokedForExecuting = YES;
    }];

    self.executingObserver.queue = nil;
    
    STAssertFalse(observerInvokedForExecuting, @"");

    // start the self.observedObject and make sure the observer on -isExecuting is
    // triggered
    [self.observedObject start];
    STAssertTrue(observerInvokedForExecuting, @"");
}

@end

@implementation KVOTestObject
@synthesize foobar = m_foobar;
@end
