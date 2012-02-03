//
//  PROKeyValueCodingProxy.h
//  Proton
//
//  Created by Justin Spahr-Summers on 03.02.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Supports key-value coding on arbitrary key paths, invoking blocks to provide
 * the key-value coding behavior.
 *
 * This object will behave like another object (the one it's initialized with)
 * for most purposes, but key-value coding messages will be treated specially,
 * and result in an invocation of one of the receiver's blocks.
 */
@interface PROKeyValueCodingProxy : NSObject

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to proxy calls to the given object without
 * a starting key path.
 *
 * This means that any key-value coding messages sent to the receiver will
 * pass the provided key directly to the receiver's callback blocks.
 *
 * @param object An object for the receiver to forward non-key-value-coding
 * messages to. This must not be `nil`.
 */
- (id)initWithProxiedObject:(id)object;

/**
 * Initializes the receiver to proxy calls to the given object at the given key
 * path.
 *
 * This means that any key-value coding messages sent to the receiver will
 * append the provided key to `keyPath`. The combined result will be the key
 * path provided to each of the receiver's callback blocks.
 *
 * This is the designated initializer for this class.
 *
 * @param object An object for the receiver to forward non-key-value-coding
 * messages to. This must not be `nil`.
 * @param keyPath The key path that the receiver should consider `object` to be
 * at.
 */
- (id)initWithProxiedObject:(id)object keyPath:(NSString *)keyPath;

/**
 * @name Proxied Key Path
 */

/**
 * The key path to this specific proxy, or `nil` if this proxy is the start of
 * a key path.
 */
@property (nonatomic, copy, readonly) NSString *proxiedKeyPath;

/**
 * The object being proxied.
 */
@property (nonatomic, strong, readonly) id proxiedObject;

/**
 * Creates and returns a new proxy object with the given proxied object and key
 * path, but the same callback blocks as the receiver.
 *
 * @param object The object to pass to <initWithProxiedObject:keyPath:>.
 * @param keyPath The key path to pass to <initWithProxiedObject:keyPath:>.
 */
- (PROKeyValueCodingProxy *)proxyWithObject:(id)object keyPath:(NSString *)keyPath;

/**
 * @name Key-Value Coding Callbacks
 */

/**
 * If not `nil`, invoked when a `setValue:forKey:` or `setValueForKeyPath:`
 * message is sent to the receiver.
 *
 * This key path passed to this block will be the key or key path provided with
 * the message, appended to the receiver's `keyPath`.
 */
@property (nonatomic, copy) void (^setValueForKeyPathBlock)(id value, NSString *keyPath);

/**
 * If not `nil`, invoked when a `valueForKey:` or `valueForKeyPath:` message is
 * sent to the receiver.
 *
 * This key path passed to this block will be the key or key path provided with
 * the message, appended to the receiver's `keyPath`.
 */
@property (nonatomic, copy) id (^valueForKeyPathBlock)(NSString *keyPath);

/**
 * If not `nil`, invoked when a `mutableArrayValueForKey:` or
 * `mutableArrayValueForKeyPath:` message is sent to the receiver.
 *
 * This key path passed to this block will be the key or key path provided with
 * the message, appended to the receiver's `keyPath`.
 */
@property (nonatomic, copy) NSMutableArray *(^mutableArrayValueForKeyPathBlock)(NSString *keyPath);

@end
