//
//  PROTransformer.h
//  Proton
//
//  Created by Justin Spahr-Summers on 17.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Proton/EXTConcreteProtocol.h>

@class PROTransformation;

/**
 * A concrete protocol representing an object that can apply
 * a <PROTransformation> "in-place."
 *
 * Implementors of this protocol do not need to actually apply the
 * <PROTransformation> themselves. Typically, views and view controllers will
 * implement this protocol to form a "transformer chain," which is similar to
 * a responder chain, but for the propagation of model changes. Such
 * a transformer chain would ultimately end at a <PROModelController>, which is
 * capable of applying the transformation to the model and notifying the rest of
 * the application of the change.
 */
@protocol PROTransformer <NSObject>
@required

    /**
     * @name Transformer Chain
     */

    /**
     * The next transformer in the chain, or `nil` if this is the end of the
     * transformer chain.
     */
    @property (nonatomic, weak) id<PROTransformer> nextTransformer;

@concrete
    
    /**
     * @name Performing Transformations
     */

    /**
     * Asks the receiver to perform the given transformation upon its model
     * object. Returns `YES` if the transformation succeeded. If the
     * transformation failed, `NO` is returned and `error` is set to the error
     * that occurred.
     *
     * If the receiver needs to wrap the transformation in another compound
     * transformation (for instance, to index into an array or dictionary), this
     * method can be overridden to add to the given transformation, then invoke
     * the method on the <nextTransformer>, passing the receiver as the new
     * `sender`.
     *
     * The default implementation of this method simply calls through to the
     * <nextTransformer>. `sender` is left unmodified.
     *
     * @param transformation The transformation to attempt to perform upon the
     * model.
     * @param sender The transformer that requested this transformation. For the
     * initial call, this would typically be `self`. If any transformer modifies
     * the transformation along the way, it should become the new sender.
     * @param error If not `NULL`, and this method returns `NO`, this should be
     * set to any error that occurred.
     */
    - (BOOL)performTransformation:(PROTransformation *)transformation sender:(id<PROTransformer>)sender error:(NSError **)error;

@end
