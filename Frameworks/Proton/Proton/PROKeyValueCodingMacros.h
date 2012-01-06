//
//  PROKeyValueCodingMacros.h
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * If the given symbol `KEY` is a valid property on the given `OBJECT`, returns
 * an `NSString` representing the `KEY`. If the `KEY` is not valid,
 * a compile-time error will result.
 *
 * This can be used to validate keys and key paths used with key-value coding
 * and other runtime facilities.
 *
 * @param OBJECT The object which should contain property `KEY`.
 * @param KEY The name of a property on the `OBJECT`, as a symbol. You may also
 * name descendant properties (e.g., `object.dictionary.key`) here, in which
 * case the path will be checked for validity. Key-value path operators (those
 * beginning with `@`) are not supported.
 */
#define PROKeyForObject(OBJECT, KEY) \
    ((void)(NO && ((void)OBJECT.KEY, NO)), @ # KEY )
