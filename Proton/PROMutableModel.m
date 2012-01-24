//
//  PROMutableModel.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModel.h"
#import "PROKeyValueCodingMacros.h"
#import "PROModel.h"
#import "PROModelController.h"
#import "PROMultipleTransformation.h"

/**
 * This class should avoid as many properties as possible, since it
 * functions like a proxy.
 */
@interface PROMutableModel () {
    /**
     * The model managed by this object, as transformed by everything in
     * <m_transformations>.
     */
    PROModel *m_latestModel;

    /**
     * Transformations representing all of the changes made so far, with the
     * latest transformation at the end of the array.
     */
    NSMutableArray *m_transformations;
}

@end

@implementation PROMutableModel

#pragma mark Properties

@synthesize modelController = m_modelController;

#pragma mark Initialization

- (id)init {
    self = [super init];
    if (!self)
        return nil;

    m_transformations = [[NSMutableArray alloc] init];
    return self;
}

- (id)initWithModel:(PROModel *)model; {
    if (!model)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    m_latestModel = [model copy];
    return self;
}

- (id)initWithModelController:(PROModelController *)modelController; {
    if (!modelController)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    m_latestModel = [modelController.model copy];
    m_modelController = modelController;
    return self;
}

#pragma mark Saving

- (BOOL)save:(NSError **)error; {
    if (!m_modelController || ![m_transformations count])
        return YES;

    PROMultipleTransformation *transformation = [[PROMultipleTransformation alloc] initWithTransformations:m_transformations];
    if (![m_modelController performTransformation:transformation error:error]) {
        return NO;
    }

    // "flush" our model object, to get the latest version
    m_latestModel = [m_modelController.model copy];
    
    // get rid of our record of transformations, now that they're saved
    [m_transformations removeAllObjects];

    return YES;
}

#pragma mark Forwarding

- (BOOL)respondsToSelector:(SEL)selector {
    return [m_latestModel respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return m_latestModel;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:m_latestModel];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [m_latestModel methodSignatureForSelector:selector];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    PROModel *model = [coder decodeObjectForKey:@"model"];
    if (!model)
        return nil;

    self = [self init];
    if (!self)
        return nil;

    m_latestModel = model;
    m_modelController = [coder decodeObjectForKey:PROKeyForObject(self, modelController)];
    m_transformations = [[coder decodeObjectForKey:@"transformations"] mutableCopy];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:m_latestModel forKey:@"model"];
    [coder encodeObject:m_transformations forKey:@"transformations"];

    if (m_modelController)
        [coder encodeObject:m_modelController forKey:PROKeyForObject(self, modelController)];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone; {
    return [m_latestModel copy];
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone; {
    PROMutableModel *model = [[[self class] alloc] init];

    model->m_latestModel = [m_latestModel copy];
    model->m_transformations = [m_transformations mutableCopy];
    model->m_modelController = self.modelController;

    return model;
}

#pragma mark NSKeyValueCoding

#pragma mark NSObject protocol

- (NSUInteger)hash {
    return [m_latestModel hash];
}

- (BOOL)isEqual:(id)model {
    if ([model isKindOfClass:[PROModel class]]) {
        return [m_latestModel isEqual:model];
    } else if ([model isKindOfClass:[PROMutableModel class]]) {
        PROMutableModel *mutableModel = model;
        return [m_latestModel isEqual:mutableModel->m_latestModel];
    } else {
        return NO;
    }
}

- (BOOL)isProxy {
    return YES;
}

@end
