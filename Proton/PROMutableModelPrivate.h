//
//  PROMutableModelPrivate.h
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModel.h"

/**
 * Private extensions necessary for <PROMutableModel> that have to be compiled
 * without ARC enabled.
 */
@interface PROMutableModel (Private)

/**
 * Allocates a class by the given name, and subclassing the given class, and
 * runs the given block before registering it with the runtime.
 *
 * Returns the fully constructed and registered class object, or `nil` if an
 * error occurs.
 *
 * @param className The name of the new class to create.
 * @param superclass The superclass of the new class.
 * @param block A block to execute after allocating the new class, but before
 * registering it with the runtime. The block is passed the newly-created class
 * object.
 */
+ (Class)createClass:(NSString *)className superclass:(Class)superclass usingBlock:(void (^)(Class newClass))block;

@end
