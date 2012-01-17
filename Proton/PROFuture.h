//
//  PROFuture.h
//  Proton
//
//  Created by Justin Spahr-Summers on 24.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Represents a future, which is the delayed result of a computation.
 *
 * This class is thread-safe.
 */
@interface PROFuture : NSProxy

// the documentation below uses a different comment style so that code blocks
// are properly included in the generated documentation

/**

Creates and returns a proxy for the result of the given block.

When the proxy receives its first message that requires the full object, the
block will be executed, and the resulting object will receive that message
and all further messages.

Typically, the object returned from this method is assigned to a variable of
the type of object expected in the future:

    NSString *originalString = @"foobar";

    NSString *newString = [PROFuture futureWithBlock:^{
        return [originalString someExpensiveTransformation];
    }];

@param block A block which performs some task and returns an object (which
the receiver will stand in for). If the block returns `nil`, messages are
treated as if sent to `EXTNil`.

*/
+ (id)futureWithBlock:(id (^)(void))block;

/**

Forces a given future to resolve, returning the resulting value.

The future is guaranteed to be set up to forward all messages by the time
this method returns.

To begin resolving a future asynchronously without waiting for it to
complete, simply resolve it in the background:

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [PROFuture resolveFuture:future];
    });

@param future The future to resolve.

*/
+ (id)resolveFuture:(PROFuture *)future;

@end
