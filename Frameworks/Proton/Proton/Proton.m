//
//  Proton.m
//  Proton
//
//  Created by Justin Spahr-Summers on 29.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/DDLog.h>
#import <Proton/DDASLLogger.h>
#import <Proton/DDTTYLogger.h>

#ifdef DEBUG
    int ddLogLevel = LOG_LEVEL_INFO;
#else
    int ddLogLevel = LOG_LEVEL_ERROR;
#endif

// automatically sets up an ASL and TTY logger at startup
__attribute__((constructor))
static void initializeLogging (void) {
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
}

