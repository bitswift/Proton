//
//  PROAssert.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/PROBacktraceFunctions.h>
#import <Proton/PROLogging.h>

/**
 * Documents an assumption that `COND` is true, non-zero, or non-nil, returning
 * `YES` if the assumption is correct.
 *
 * If the assumption is incorrect, an error message is logged using the given
 * format string and arguments. In a Debug build, the application will then
 * immediately abort. In a Release build, execution continues, and the macro
 * returns `NO`.
 *
 * This macro can be used like a stronger form of error-checking, or a weaker
 * form of assertion. It's extremely useful when a given condition "should"
 * never be true, but pathological cases might invalidate such an assumption,
 * and thus handler code needs to be written for it regardless.
 */
#define PROAssert(COND, ...) \
    (__builtin_expect(!!(COND), 1) || (PROAssertionFailure(# COND, __VA_ARGS__), 0))

#if defined(DEBUG) && !defined(NDEBUG)
    #define PROAssertionFailure(CONDSTR, ...) \
        PROAbortWithMessage(@"Assertion \"%s\" failed: %@", CONDSTR, [NSString stringWithFormat:__VA_ARGS__])
#else
    #define PROAssertionFailure(CONDSTR, ...) \
        SYNC_LOG_MACRO(LOG_LEVEL_VERBOSE, LOG_FLAG_ERROR, 0, @"Assertion \"%s\" failed: %@", CONDSTR, [NSString stringWithFormat:__VA_ARGS__])
#endif
