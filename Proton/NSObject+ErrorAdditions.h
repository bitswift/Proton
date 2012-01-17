//
//  NSObject+ErrorAdditions.h
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSObject` to make error handling easier.
 */
@interface NSObject (ErrorAdditions)

/**
 * Returns an `NSError` with given error code, localized description and recovery suggestion.
 *
 * To use this method, you must implement an `+errorDomain` method on the class of the receiver, which will be used for the domain of the error.
 *
 * @param code The code of the returned error.
 * @param description The localized description of the error, which may be presented to the user as an alert title.
 * @param recoverySuggestion The localized recovery suggestion of the error, which may be presented to the user as an alert message.
 */
- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description recoverySuggestion:(NSString *)recoverySuggestion;

@end
