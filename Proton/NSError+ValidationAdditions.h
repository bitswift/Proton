//
//  NSError+ValidationAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 01.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to `NSError` that make it easier to manipulate Core Data
 * validation errors.
 */
@interface NSError (ValidationAdditions)

/**
 * Creates and returns an `NSValidationMultipleErrorsError` that combines the
 * receiver and the given error for the `NSDetailedErrorsKey`.
 *
 * If the receiver is already a `NSValidationMultipleErrorsError`, the given
 * error object is simply appended to the existing list of errors.
 *
 * @param error A validation error to combine with the receiver.
 */
- (NSError *)multipleValidationErrorByAddingError:(NSError *)error;

@end
