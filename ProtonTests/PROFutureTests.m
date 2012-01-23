//
//  PROFutureTests.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/EXTNil.h>
#import <Proton/PROFuture.h>

SpecBegin(PROFuture)
    __block id future = nil;
    
    describe(@"future returning nil", ^{
        before(^{
            future = [PROFuture futureWithBlock:^ id {
                return nil;
            }];

            expect(future).not.toBeNil();
        });

        after(^{
            expect(future).toEqual([EXTNil null]);
        });

        it(@"should resolve synchronously", ^{
            [PROFuture resolveFuture:future];
        });

        it(@"should resolve implicitly", ^{
            NSString *newString = [future stringByAppendingString:@"buzz"];

            expect(newString).toBeNil();
        });
    });

    describe(@"future returning string", ^{
        before(^{
            future = [PROFuture futureWithBlock:^ id {
                return @"foobar";
            }];

            expect(future).not.toBeNil();
        });

        after(^{
            expect(future).toEqual(@"foobar");
        });

        it(@"should resolve synchronously", ^{
            [PROFuture resolveFuture:future];
        });

        it(@"should resolve implicitly", ^{
            NSString *newString = [future stringByAppendingString:@"buzz"];

            expect(newString).toEqual(@"foobarbuzz");
        });
    });

    describe(@"futures should only resolve once", ^{
        __block BOOL resolved;

        before(^{
            resolved = NO;

            future = [PROFuture futureWithBlock:^{
                expect(resolved).toBeFalsy();

                resolved = YES;
                return @"foobar";
            }];
        });

        it(@"implicitly", ^{
            [future stringByAppendingString:@"buzz"];

            expect(resolved).toBeTruthy();

            [future stringByAppendingString:@"buzz"];
        });

        it(@"explicitly", ^{
            [PROFuture resolveFuture:future];

            expect(resolved).toBeTruthy();

            [PROFuture resolveFuture:future];
        });
    });

    it(@"should be thread-safe", ^{
        future = [PROFuture futureWithBlock:^{
            return @"thread ";
        }];

        dispatch_apply(10, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
            NSString *threadString = [future stringByAppendingFormat:@"%zu", i];
            NSString *expectedString = [NSString stringWithFormat:@"thread %zu", i];

            expect(threadString).toEqual(expectedString);
        });

        expect(future).toEqual(@"thread ");
    });

    it(@"should release its resolved object upon destruction", ^{
        __weak NSObject *weakObject = nil;

        @autoreleasepool {
            __autoreleasing NSObject *object = [[NSObject alloc] init];
            expect(object).not.toBeNil();

            weakObject = object;

            __autoreleasing PROFuture *localFuture = [PROFuture futureWithBlock:^{
                return weakObject;
            }];

            [PROFuture resolveFuture:localFuture];
        }

        // destroying the future should've released the object it resolved
        expect(weakObject).toBeNil();
    });

    after(^{
        future = nil;
    });

SpecEnd

