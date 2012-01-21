//
//  PROBacktraceFunctions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROBacktraceFunctions.h"
#import <execinfo.h>
#import <Proton/PROLogging.h>

/*
 * The maximum number of functions/methods included in generated backtraces.
 */
#define PROTON_CALLSTACK_MAXIMUM 128

void PROAbortWithMessage (NSString *format, ...) {
    // log the message
    {
        va_list args;
        va_start(args, format);

        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];

        va_end(args);

        // 'message' should not be passed as the format string, as doing so would be
        // unsafe
        DDLogError(@"%@", message);

        [DDLog flushLog];
    }

    // capture and log the backtrace
    {
        void *callstack[PROTON_CALLSTACK_MAXIMUM];
        int frames = backtrace(callstack, PROTON_CALLSTACK_MAXIMUM);

        char **symbols = backtrace_symbols(callstack, frames);
        for (int i = 0; i < frames; ++i) {
            fprintf(stderr, "%s\n", symbols[i]);
        }

        // make sure the backtrace finishes printing
        fflush(stderr);

        // this probably isn't necessary, since we're about to crash anyways
        free(symbols);
    }

    abort();
    __builtin_unreachable();
}

