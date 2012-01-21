//
//  PROLogging.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/DDASLLogger.h>
#import <Proton/DDLog.h>
#import <Proton/DDTTYLogger.h>

/**
 * The default logging level for Proton and projects linking to it.
 *
 * This logging level is based on the configuration with which Proton was built.
 *
 * Individual files can declare a `static int ddLogLevel` variable, which will
 * override this one.
 */
extern int ddLogLevel;

// disable asynchronous logging in Debug builds by default
#ifdef DEBUG
    #undef LOG_ASYNC_ENABLED
    #define LOG_ASYNC_ENABLED NO
#endif
