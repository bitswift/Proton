//
//  PROLogging.m
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROLogging.h"

#ifdef DEBUG
    int ddLogLevel = LOG_LEVEL_INFO;
#else
    int ddLogLevel = LOG_LEVEL_ERROR;
#endif

/*
 * Formats TTY (Xcode console) logs with the caller's function name and line
 * number.
 */
@interface PROTTYLogFormatter : NSObject <DDLogFormatter>
@end

/*
 * Formats ASL (system console) logs with the caller's file and line number, to
 * reveal fewer implementation details than <PROTTYLogFormatter>.
 */
@interface PROASLLogFormatter : NSObject <DDLogFormatter>
@end

// automatically sets up an ASL and TTY logger at startup
__attribute__((constructor))
static void initializeLogging (void) {
    [DDASLLogger sharedInstance].logFormatter = [[PROASLLogFormatter alloc] init];
    [DDLog addLogger:[DDASLLogger sharedInstance]];

    [DDTTYLogger sharedInstance].logFormatter = [[PROTTYLogFormatter alloc] init];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
}

@implementation PROTTYLogFormatter
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage; {
    return [[NSString alloc] initWithFormat:@"%s:%i: %@", logMessage->function, logMessage->lineNumber, logMessage->logMsg];
}
@end

@implementation PROASLLogFormatter
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage; {
    // use short filename instead of function
    return [[NSString alloc] initWithFormat:@"%@:%i: %@", [logMessage fileName], logMessage->lineNumber, logMessage->logMsg];
}
@end

