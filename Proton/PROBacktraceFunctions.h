//
//  PROBacktraceFunctions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 21.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Logs the given format string and arguments, captures and logs the current
 * backtrace to `stderr`, and then aborts.
 *
 * This function never returns.
 */
void PROAbortWithMessage (NSString *format, ...) __attribute__((noreturn));
