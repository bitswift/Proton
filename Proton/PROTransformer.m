//
//  PROTransformer.m
//  Proton
//
//  Created by Justin Spahr-Summers on 17.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import <Proton/PROTransformer.h>

@concreteprotocol(PROTransformer)

#pragma mark Properties

- (id<PROTransformer>)nextTransformer {
    NSAssert(NO, @"%@ must be implemented by classes conforming to <PROTransformer>", NSStringFromSelector(_cmd));
    
    return nil;
}

- (void)setNextTransformer:(id<PROTransformer>)transformer {
    NSAssert(NO, @"%@ must be implemented by classes conforming to <PROTransformer>", NSStringFromSelector(_cmd));
}

#pragma mark Transformation

- (BOOL)performTransformation:(PROTransformation *)transformation sender:(id<PROTransformer>)sender; {
    return [self.nextTransformer performTransformation:transformation sender:sender];
}

@end
