//
//  PROModelControllerPrivate.h
//  Proton
//
//  Created by Justin Spahr-Summers on 28.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROModelController.h"

/**
 * Private functionality of <PROModelController> that needs to be exposed to
 * other parts of the framework.
 */
@interface PROModelController (Private)
/**
 * Replaces the <model>, optionally updating other model controllers on the
 * receiver to match.
 *
 * @param model The new model object to set on the receiver.
 * @param replacing If `YES`, all existing model controllers will be destroyed
 * and recreated from the models in `model`. If `NO`, model controllers are
 * assumed to be updated elsewhere, and will not be modified.
 */
- (void)setModel:(PROModel *)model replacingModelControllers:(BOOL)replacing;
@end
