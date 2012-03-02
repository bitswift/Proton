//
//  PRONSObjectAdditionsTests.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/Proton.h>
#import <libkern/OSAtomic.h>

@interface ErrorTestClass : NSObject
@end

SpecBegin(PRONSObjectAdditions)

    it(@"should determine equality even with nil values", ^{
        id obj1 = @"Test1";
        id obj2 = @"Test2";

        expect(NSEqualObjects(nil, nil)).toBeTruthy();
        expect(NSEqualObjects(nil, obj1)).toBeFalsy();
        expect(NSEqualObjects(obj1, nil)).toBeFalsy();
        expect(NSEqualObjects(obj1, obj1)).toBeTruthy();
        expect(NSEqualObjects(obj1, obj2)).toBeFalsy();
    });

    it(@"should create errors using +errorDomain", ^{
        ErrorTestClass *obj = [[ErrorTestClass alloc] init];
        expect(obj).not.toBeNil();

        NSInteger errorCode = 1000;
        NSString *errorDescription = @"DESCRIPTION";
        NSString *errorRecoverySuggestion = @"RECOVERY SUGGESTION";

        NSError *error = [obj errorWithCode:errorCode description:errorDescription recoverySuggestion:errorRecoverySuggestion];
        expect(error).not.toBeNil();

        expect(error.code).toEqual(errorCode);
        expect(error.localizedDescription).toEqual(errorDescription);
        expect(error.localizedRecoverySuggestion).toEqual(errorRecoverySuggestion);
        expect(error.domain).toEqual([[obj class] errorDomain]);
    });

    describe(@"PROKeyValueObserver additions", ^{
        __block NSBlockOperation *operation;
        __block __weak PROKeyValueObserver *observer;

        __block NSString *keyPath;
        __block PROKeyValueObserverBlock block;

        // set to zero by default -- will be verified on the observer afterward
        __block NSKeyValueObservingOptions options;

        before(^{
            operation = [NSBlockOperation blockOperationWithBlock:^{}];

            keyPath = @"isExecuting";
            options = 0;

            block = [^(NSDictionary *changes){
                STFail(@"Observer block should not trigger for any tests");
            } copy];
        });

        after(^{
            observer = nil;
        });

        describe(@"adding an observer owned by an object", ^{
            it(@"should add without options", ^{
                // all behavior here is handled by the before and after blocks
            });

            it(@"should add with options", ^{
                options = NSKeyValueObservingOptionNew;
            });

            after(^{
                @autoreleasepool {
                    if (options)
                        observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath options:options usingBlock:block];
                    else
                        observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];

                    expect(observer).not.toBeNil();
                }

                // observers should not be deallocated when an autorelease pool
                // is popped
                expect(observer).not.toBeNil();

                expect(observer.target).toEqual(operation);
                expect(observer.keyPath).toEqual(keyPath);
                expect(observer.options).toEqual(options);
                expect(observer.block).toEqual(block);
            });
        });

        it(@"should remove a specific observer", ^{
            __weak PROKeyValueObserver *observer;

            @autoreleasepool {
                observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
                [self removeOwnedObserver:observer];
            }

            expect(observer).toBeNil();
        });

        it(@"should remove all observers", ^{
            __weak PROKeyValueObserver *observer;
            __weak PROKeyValueObserver *secondObserver;

            @autoreleasepool {
                observer = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
                secondObserver = [operation addObserverOwnedByObject:self forKeyPath:@"isFinished" usingBlock:block];

                [self removeAllOwnedObservers];
            }

            expect(observer).toBeNil();
            expect(secondObserver).toBeNil();
        });

        it(@"should add observers in a thread-safe way", ^{
            // the number of observers to test concurrently
            const size_t count = 10;

            __weak PROKeyValueObserver * volatile *observers = (__weak id *)malloc(sizeof(*observers) * count);
            @onExit {
                free((void *)observers);
            };

            @autoreleasepool {
                dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index){
                    // each thread has its own autorelease pool -- verify that it does not
                    // destroy the observer created on this thread
                    @autoreleasepool {
                        observers[index] = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];
                    }
                });

                // make sure all stores complete
                OSMemoryBarrier();
            }

            // verify that each observer was instantiated correctly and is still alive
            for (size_t i = 0;i < count;++i) {
                __weak PROKeyValueObserver *observer = observers[i];
                expect(observer).not.toBeNil();

                expect(observer.target).toEqual(operation);
                expect(observer.keyPath).toEqual(keyPath);
                expect(observer.options).toEqual(0);
                expect(observer.block).toEqual(block);
            }
        });

        it(@"should remove observers in a thread-safe way", ^{
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

            @autoreleasepool {
                dispatch_apply(count, queue, ^(size_t index){
                    @autoreleasepool {
                        observers[index] = [operation addObserverOwnedByObject:self forKeyPath:keyPath usingBlock:block];

                        dispatch_group_async(group, queue, ^{
                            @autoreleasepool {
                                // make sure the store to this index completes before trying to
                                // remove it
                                OSMemoryBarrier();
                            
                                [self removeOwnedObserver:observers[index]];
                            }
                        });
                    }
                });

                // wait for all removals to complete as well
                dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

                // make sure all stores and weak reference updates complete
                OSMemoryBarrier();
            }

            // verify that each observer was removed correctly and niled out
            for (size_t i = 0;i < count;++i) {
                expect(observers[i]).toBeNil();
            }
            
            // start the operation and make sure no observers are triggered
            [operation start];
            [operation waitUntilFinished];
        });
    });

SpecEnd

@implementation ErrorTestClass
+ (NSString *)errorDomain {
    return @"PRONSObjectAdditionsTestsErrorDomain";
}

@end
