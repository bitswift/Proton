//
//  PROMutableModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PROModel;
@class PROModelController;

/**
 * Proxies a <PROModel> and provides the illusion of mutability, to make certain
 * usage patterns easier.
 *
 * This class will automatically provide setters for any properties that exist
 * on the underlying <PROModel>, and will support key-value coding and key-value
 * observing on all of the model object's properties.
 *
 * Internally, a record of <PROTransformation> objects is kept that describes
 * the changes being made to the <PROModel>. When <save:> is invoked, it will
 * attempt to propagate those changes back to a <PROModelController>.
 *
 * If an instance of this class receives a message it does not understand, the
 * message is automatically forwarded to the underlying <PROModel> object.
 *
 * @warning **Important:** Properties containing other <PROModel> instances are
 * not automatically made mutable when using this class.
 *
 * This class is not thread-safe.
 */
@interface PROMutableModel : NSObject <NSCoding, NSCopying, NSMutableCopying>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver to proxy the given model object. Returns `nil` if
 * the given model is `nil`.
 *
 * Any changes made to the receiver will not be propagated back to any model
 * controller. Invoking <save:> will have no effect.
 *
 * @param model The model object that the receiver should proxy.
 */
- (id)initWithModel:(PROModel *)model;

/**
 * Initializes the receiver to proxy the model object of the given controller.
 * Returns `nil` if the given model is `nil`.
 *
 * Invoking <save:> after making changes to the receiver will attempt to
 * propagate those changes back to the model controller.
 *
 * @param modelController The model controller that owns the model which should
 * be proxied.
 */
- (id)initWithModelController:(PROModelController *)modelController;

/**
 * @name Model Controller
 */

/**
 * The model controller specified at initialization, or `nil` if the receiver
 * was not initialized with a model controller.
 */
@property (nonatomic, strong, readonly) PROModelController *modelController;

/**
 * @name Copying
 */

/**
 * Returns a <PROModel> object representing the current state of the receiver.
 */
- (id)copyWithZone:(NSZone *)zone;

/**
 * Returns a new <PROMutableModel>, initialized to the same state as the
 * receiver.
 */
- (id)mutableCopyWithZone:(NSZone *)zone;

/**
 * @name Saving Changes
 */

/**
 * Attempts to save changes made on the receiver back to its <modelController>.
 * Returns `YES` upon success. If the save is not successful, `NO` is returned
 * and `error` is set to the error that occurred.
 *
 * If the receiver does not have a <modelController>, this method returns `YES`
 * without doing anything.
 *
 * @param error If not `NULL`, and this method returns `NO`, this may be set to
 * the error that occurred.
 */
- (BOOL)save:(NSError **)error;

@end
