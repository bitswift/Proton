//
//  PROMutableModel.h
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PROKeyedObject.h"

@class PROModel;
@class PROTransformation;
@class PROTransformationLogEntry;

// the documentation below uses a different comment style so that code blocks
// are properly included in the generated documentation

/**

`@mutable` starts declaring **but does not define** a mutable subclass of an immutable
<PROModel> subclass. This macro should be closed with `@end`.

This can be used to help the compiler out with static typing and make property declarations
clearer. To use this macro, redeclare any `readonly` properties as `readwrite` inside the
interface block, and simply give variables the generated `MUTABLE_SUBCLASS` type:

    // MyModel.h
    
    @interface MyModel : PROModel
    @property (nonatomic, copy, readonly) NSString *someString;
    @end

    @mutable(MyMutableModel, MyModel)
    @property (nonatomic, copy, readwrite) NSString *someString;
    @end

    // MyView.h

    @property (nonatomic, strong) MyMutableModel *mutableModel;

@warning **Important:** The class declared by this macro **should not be implemented**.
Instead, use instances of <PROMutableModel>, which will automatically implement the correct
properties and behaviors behind-the-scenes.

*/
#define mutable(MUTABLE_SUBCLASS, IMMUTABLE_SUPERCLASS) \
    interface MUTABLE_SUBCLASS : IMMUTABLE_SUPERCLASS <PROMutableModel>

/**

Represents a mutable model object.

Typically, this protocol is applied to <PROModel> variables or properties to
indicate that they actually hold <PROMutableModel> instances, and are simply duck
typed to <PROModel>:

    // MyModel.h
    
    @interface MyModel : PROModel
    @property (nonatomic, copy, readonly) NSString *someString;
    @end

    // MyView.h
    
    @property (nonatomic, strong) MyModel<PROMutableModel> *mutableModel;

Also see the `@mutable` macro, which makes this even more useful.

*/
@protocol PROMutableModel <PROKeyedObject, NSCoding, NSCopying, NSMutableCopying>
@required

/**
 * @name Copying
 */

/**
 * Atomically copies the receiver into an immutable <PROModel> object.
 *
 * The same object may be returned across multiple calls to this method if the
 * data has not changed in the interim.
 *
 * @param zone Unused.
 */
- (id)copyWithZone:(NSZone *)zone;

/**
 * Atomically copies the receiver into a new <PROMutableModel>.
 *
 * @param zone Unused.
 */
- (id)mutableCopyWithZone:(NSZone *)zone;

/**
 * @name Applying Transformations
 */

/**
 * Atomically applies the given transformation to the receiver, returning `YES`
 * upon success. If the transformation fails, `NO` is returned and `error` is
 * set to the error that occurred.
 *
 * If the transformation succeeds, it is added to an internal "transformation
 * log," which can be used to replay transformations in reverse and retrieve an
 * older copy of the receiver. See <transformationLogEntry> for more
 * information.
 *
 * @param transformation The transformation to attempt to apply.
 * @param error If not `NULL`, this is set to any error that occurs. This
 * argument will only be set if the method returns `NO`.
 *
 * @warning **Important:** This method briefly synchronizes with the main thread
 * before committing the transformation, to make strong guarantees about data
 * consistency on the main thread. This means that invoking this method from
 * a background thread may block the caller for an indeterminate period of time.
 */
- (BOOL)applyTransformation:(PROTransformation *)transformation error:(NSError **)error;

/**
 * @name Transformation Log
 */

/**
 * The maximum number of <PROTransformation> instances to include in the
 * transformation log when the receiver is archived, or zero to disable limiting
 * of the archived log.
 *
 * There is intentionally no way to limit a transformation log's in-memory size
 * limit, as doing so would introduce more problems than it would solve.
 *
 * The default value for this property is 50.
 */
@property (assign) NSUInteger archivedTransformationLogLimit;

/**
 * Retrieves the latest transformation log entry.
 *
 * The transformation log entry can later be passed to
 * <modelWithTransformationLogEntry:> or <restoreTransformationLogEntry:> to
 * retrieve the model as it existed when this method was invoked.
 */
@property (nonatomic, copy, readonly) PROTransformationLogEntry *transformationLogEntry;

/**
 * Returns the version of the receiver that corresponds to the given
 * transformation log entry, or `nil` if the entry no longer exists in the log.
 *
 * The given log entry may no longer exist if the transformation was archived
 * and trimmed to stay within the <archivedTransformationLogLimit>.
 *
 * @param transformationLogEntry An object previously returned from
 * <transformationLogEntry>.
 */
- (id)modelWithTransformationLogEntry:(PROTransformationLogEntry *)transformationLogEntry;

/**
 * Restores the version of the receiver that corresponds to the given log entry.
 * Returns `YES` on success, or `NO` if the entry no longer exists in the log.
 *
 * This method is better suited to undo and redo than
 * <modelWithTransformationLogEntry:>, since this method can rollback or update
 * a mutable model in-place, and without any duplication of data.
 *
 * @param transformationLogEntry An object previously returned from
 * <transformationLogEntry>.
 */
- (BOOL)restoreTransformationLogEntry:(PROTransformationLogEntry *)transformationLogEntry;

@end

/**

Proxies a <PROModel> and provides the illusion of mutability, to make certain
usage patterns easier.

This class will automatically provide setters for any properties that exist
on the underlying <PROModel>, and will support key-value coding and key-value
observing on all of the model object's properties.

Internally, a record of <PROTransformation> objects is kept that describes
the changes being made to the <PROModel>. Entries from this log can be retrieved
with <[PROMutableModel transformationLogEntry]> and later restored using
<[PROMutableModel modelWithTransformationLogEntry:]> or <[PROMutableModel
restoreTransformationLogEntry:]>.

If an instance of this class receives a message it does not understand, the
message is automatically forwarded to the underlying <PROModel> object.

@warning **Important:** You should not subclass this class. If you want to make
access to setters more convenient, make use of the <PROMutableModel> protocol or
the `@mutable` macro.

 */
@interface PROMutableModel : NSObject <PROMutableModel>

/**
 * @name Initialization
 */

/**
 * Initializes the receiver with the given model object. Returns `nil` if the
 * given model is `nil`.
 *
 * @param model The <PROModel> or <PROMutableModel> object that the receiver
 * should be a mutable copy of.
 */
- (id)initWithModel:(id)model;

@end
