//
//  PROLogging.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "DDASLLogger.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#ifdef PROTON_LOGGING_LEVEL
    static int ddLogLevel = PROTON_LOGGING_LEVEL;
#endif

// disable asynchronous logging in Debug builds by default
#ifdef DEBUG
    #undef LOG_ASYNC_ENABLED
    #define LOG_ASYNC_ENABLED NO
#endif
