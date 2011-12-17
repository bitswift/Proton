//
//  PRODictionaryModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROModel.h>

/**
 * An immutable dictionary model object.
 *
 * Instances of this class can be created directly and used similarly to
 * dictionaries (via key-value coding), with additional conveniences for
 * immutability and transformation.
 */
@interface PRODictionaryModel : PROModel

/**
 * @name Initialization
 */

/**
 * Initializes the properties of the receiver using the keys and values of
 * a dictionary.
 *
 * Unlike <PROModel>, this class will consider any key valid.
 *
 * This is the designated initializer for this class.
 *
 * @param dictionary The property keys and values to set on the receiver. This
 * argument can be `nil`.
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
