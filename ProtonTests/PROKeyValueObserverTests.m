//
//  PROKeyValueObserverTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROKeyValueObserver.h>
#import <Proton/SDQueue.h>

@interface KVOTestObject : NSObject
@property (nonatomic, strong) NSString *foobar;
@end

SpecBegin(PROKeyValueObserver)

    __block id observedObject = nil;

    __block PROKeyValueObserver *observer = nil;
    __block __weak PROKeyValueObserver *weakObserver;

    __block BOOL observerInvoked;

    __block NSString *keyPath;
    __block NSKeyValueObservingOptions options;
    __block SDQueue *queue;
    __block PROKeyValueObserverBlock block;

    before(^{
        observerInvoked = NO;

        keyPath = nil;
        options = 0;
        queue = [SDQueue currentQueue];
        block = nil;
    });

    after(^{
        expect(observer.executing).toBeFalsy();
        
        // tear down observers before the observed object
        observer = nil;
        observedObject = nil;
    });

    void (^verifyObserverInitialization)(void) = ^{
        expect(observer).not.toBeNil();

        expect(observer.target).toEqual(observedObject);
        expect(observer.keyPath).toEqual(keyPath);
        expect(observer.options).toEqual(options);
        expect(observer.block).toEqual(block);
        expect(observer.queue).toEqual(queue);
        expect(observer.executing).toBeFalsy();
    };

    PROKeyValueObserverBlock blockWithoutOptions = ^(NSDictionary *changes){
        expect(weakObserver).not.toBeNil();

        observerInvoked = YES;
        expect(weakObserver.executing).toBeTruthy();

        // make sure the change dictionary matches the structure we expect
        expect(changes).not.toBeNil();
        expect([changes objectForKey:NSKeyValueChangeKindKey]).not.toBeNil();
        expect([changes objectForKey:NSKeyValueChangeIndexesKey]).toBeNil();

        // the change dictionary shouldn't contain any optional keys (since we
        // didn't pass in any options)
        expect([changes objectForKey:NSKeyValueChangeOldKey]).toBeNil();
        expect([changes objectForKey:NSKeyValueChangeNewKey]).toBeNil();
        expect([changes objectForKey:NSKeyValueChangeIndexesKey]).toBeNil();
        
        // this should be not present or NO (because we're not observing with
        // the "prior" option)
        expect([[changes objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue]).toBeFalsy();
    };

    describe(@"observers on NSOperation", ^{
        __block BOOL operationCompleted;

        before(^{
            keyPath = @"isFinished";

            operationCompleted = NO;
            observedObject = [NSBlockOperation blockOperationWithBlock:^{
                operationCompleted = YES;
            }];
        });

        after(^{
            expect(operationCompleted).toBeTruthy();
        });

        describe(@"without options", ^{
            before(^{
                block = blockWithoutOptions;

                weakObserver = observer = [[PROKeyValueObserver alloc]
                    initWithTarget:observedObject
                    keyPath:keyPath
                    block:block
                ];

                verifyObserverInitialization();
            });

            it(@"should trigger block", ^{
                // run the operation and make sure the observer is triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).toBeTruthy();
            });

            it(@"should not trigger block after being removed", ^{
                observer = nil;
                
                // run the operation and make sure the observer is not triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).toBeFalsy();
            });
        });

        describe(@"on background queue", ^{
            before(^{
                block = blockWithoutOptions;
                queue = [[SDQueue alloc] init];

                weakObserver = observer = [[PROKeyValueObserver alloc]
                    initWithTarget:observedObject
                    keyPath:keyPath
                    block:block
                ];

                observer.queue = queue;

                verifyObserverInitialization();
            });

            it(@"should trigger block", ^{
                // run the operation and make sure the observer is triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).isGoing.toBeTruthy();
            });
        });

        describe(@"on nil queue", ^{
            before(^{
                block = blockWithoutOptions;
                queue = nil;

                weakObserver = observer = [[PROKeyValueObserver alloc]
                    initWithTarget:observedObject
                    keyPath:keyPath
                    block:block
                ];

                observer.queue = queue;

                verifyObserverInitialization();
            });

            it(@"should trigger block", ^{
                // run the operation and make sure the observer is triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).toBeTruthy();
            });
        });

        describe(@"with options", ^{
            before(^{
                options = NSKeyValueObservingOptionNew;
                block = ^(NSDictionary *changes){
                    observerInvoked = YES;
                    expect(weakObserver.executing).toBeTruthy();

                    // make sure the change dictionary matches the structure we expect
                    expect(changes).not.toBeNil();
                    expect([changes objectForKey:NSKeyValueChangeKindKey]).not.toBeNil();
                    expect([changes objectForKey:NSKeyValueChangeIndexesKey]).toBeNil();

                    // the change dictionary should contain the new value (as a boolean
                    // NSNumber) and not the old value
                    expect([changes objectForKey:NSKeyValueChangeOldKey]).toBeNil();
                    expect([changes objectForKey:NSKeyValueChangeNewKey]).toBeKindOf([NSNumber class]);

                    // this should be not present or NO (because we're not observing with
                    // the "prior" option)
                    expect([[changes objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue]).toBeFalsy();
                };

                weakObserver = observer = [[PROKeyValueObserver alloc]
                    initWithTarget:observedObject
                    keyPath:keyPath
                    options:options
                    block:block
                ];

                verifyObserverInitialization();
            });

            it(@"should trigger block", ^{
                // run the operation and make sure the observer is triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).toBeTruthy();
            });

            it(@"should not trigger block after being removed", ^{
                observer = nil;
                
                // run the operation and make sure the observer is not triggered
                [observedObject start];
                [observedObject waitUntilFinished];

                expect(observerInvoked).toBeFalsy();
            });
        });
    });

    describe(@"observers on custom class", ^{
        before(^{
            keyPath = @"foobar";
            observedObject = [[KVOTestObject alloc] init];
            block = blockWithoutOptions;

            weakObserver = observer = [[PROKeyValueObserver alloc]
                initWithTarget:observedObject
                keyPath:keyPath
                block:block
            ];
            
            verifyObserverInitialization();
        });

        it(@"should trigger block", ^{
            [observedObject setFoobar:@"blah"];
            expect(observerInvoked).toBeTruthy();
        });

        it(@"should not trigger block after being removed", ^{
            observer = nil;

            [observedObject setFoobar:@"blah"];
            expect(observerInvoked).toBeFalsy();
        });
    });

    describe(@"observers on class cluster", ^{
        before(^{
            keyPath = @"foobar";
            observedObject = [[NSMutableDictionary alloc] init];
            block = blockWithoutOptions;

            weakObserver = observer = [[PROKeyValueObserver alloc]
                initWithTarget:observedObject
                keyPath:keyPath
                block:block
            ];
            
            verifyObserverInitialization();
        });

        it(@"should trigger block", ^{
            [observedObject setValue:@"blah" forKey:@"foobar"];
            expect(observerInvoked).toBeTruthy();
        });

        it(@"should not trigger block after being removed", ^{
            observer = nil;

            [observedObject setValue:@"blah" forKey:@"foobar"];
            expect(observerInvoked).toBeFalsy();
        });
    });

SpecEnd

@implementation KVOTestObject
@synthesize foobar = m_foobar;
@end
