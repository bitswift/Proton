//
//  PROKeyedObject.h
//  Proton
//
//  Created by Justin Spahr-Summers on 14.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A model object transformable with a <PROKeyedTransformation>.
 */
@protocol PROKeyedObject <NSCoding, NSCopying, NSObject>
@required
/**
 * Initializes the receiver with the keys and values contained in the given
 * dictionary, returning `nil` and setting `error` if any error occurs.
 *
 * Invoking <dictionaryValue> later should, if no changes have happened in the
 * meantime, return a dictionary that compares equal to `dict`.
 *
 * @param dict The keys which should be initialized on the receiver, along with
 * their corresponding values.
 * @param error If not `NULL`, and this method returns `nil`, this argument
 * _may_ be set to the error that occurred. This argument will be left
 * unmodified if this method returns a valid object.
 */
- (id)initWithDictionary:(NSDictionary *)dict error:(NSError **)error;

/**
 * Returns a dictionary containing the keys and values of the receiver.
 *
 * If the returned dictionary is then passed to <initWithDictionary:error:> on
 * another instance of the same class, the instantiated object should compare
 * equal to the receiver.
 */
- (NSDictionary *)dictionaryValue;
@end
