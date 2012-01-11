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
 * dictionary.
 *
 * Invoking <dictionaryValue> later should, if no changes have happened in the
 * meantime, return a dictionary that compares equal to `dict`.
 *
 * @param dict The keys which should be initialized on the receiver, along with
 * their corresponding values.
 */
- (id)initWithDictionary:(NSDictionary *)dict;

/**
 * Returns a dictionary containing the keys and values of the receiver.
 *
 * If the returned dictionary is then passed to <initWithDictionary:> on another
 * instance of the same class, the instantiated object should compare equal to
 * the receiver.
 */
- (NSDictionary *)dictionaryValue;
@end
