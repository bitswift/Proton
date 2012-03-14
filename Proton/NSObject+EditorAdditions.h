//
//  NSObject+EditorAdditions.h
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Extensions to the `<NSEditor>` informal protocol.
 *
 * Though methods in the `<NSEditor>` protocol do not exist on iOS, the
 * extensions provided here are generic enough to still be useful.
 */
@interface NSObject (EditorAdditions)

/**
 * @name Undo Action Name
 */

/**
 * The name that should appear for undo actions registered while the receiver is
 * editing.
 *
 * This is used by <PROManagedObjectController> to automatically set undo action
 * names appropriately.
 */
@property (nonatomic, copy) NSString *editingUndoActionName;

@end
