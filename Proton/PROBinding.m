//
//  PROBinding.m
//  Proton
//
//  Created by Justin Spahr-Summers on 31.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROBinding.h"
#import "PROKeyValueObserver.h"
#import "EXTScope.h"
#import <objc/runtime.h>

/**
 * A key used to associate an `NSMutableArray` of bindings on their owner.
 */
static char * const PROBindingOwnerAssociatedBindingsKey = "PROBindingOwnerAssociatedBindings";

@interface PROBinding ()
@property (nonatomic, weak, readwrite) id owner;
@property (nonatomic, strong, readwrite) id boundObject;

/**
 * Observes the <ownerKeyPath> of the <owner> for changes, if the key path is
 * KVO-compliant.
 */
@property (nonatomic, strong) PROKeyValueObserver *ownerObserver;

/**
 * Observes the <boundKeyPath> of the <boundObject> for changes, if the key path
 * is KVO-compliant.
 */
@property (nonatomic, strong) PROKeyValueObserver *boundObjectObserver;

/**
 * Whether the <owner> or <boundObject> is currently being updated from a change
 * to the other.
 *
 * This is used to avoid infinite recursion from both repeatedly updating.
 */
@property (nonatomic, getter = isUpdating) BOOL updating;
@end

@implementation PROBinding

#pragma mark Properties

@synthesize owner = m_owner;
@synthesize ownerKeyPath = m_ownerKeyPath;
@synthesize boundObject = m_boundObject;
@synthesize boundKeyPath = m_boundKeyPath;
@synthesize ownerObserver = m_ownerObserver;
@synthesize boundObjectObserver = m_boundObjectObserver;
@synthesize updating = m_updating;

- (BOOL)isBound {
    return self.owner != nil;
}

#pragma mark Lifecycle

+ (id)bindKeyPath:(NSString *)ownerKeyPath ofObject:(id)owner toKeyPath:(NSString *)boundKeyPath ofObject:(id)boundObject; {
    PROBinding *binding = [[PROBinding alloc] initWithOwner:owner ownerKeyPath:ownerKeyPath boundObject:boundObject boundKeyPath:boundKeyPath];
    if (!binding)
        return nil;

    // add to any existing bindings on the owner
    NSMutableArray *bindings = objc_getAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey);
    if (!bindings) {
        bindings = [NSMutableArray array];
        
        objc_setAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [bindings addObject:binding];
    return binding;
}

- (id)init {
    NSAssert(NO, @"Use -initWithOwner:ownerKeyPath:boundObject:boundKeyPath: to initialize instances of %@", [self class]);
    return nil;
}

- (id)initWithOwner:(id)owner ownerKeyPath:(NSString *)ownerKeyPath boundObject:(id)boundObject boundKeyPath:(NSString *)boundKeyPath; {
    if (!owner || !boundObject)
        return nil;

    NSParameterAssert(ownerKeyPath);
    NSParameterAssert(boundKeyPath);

    self = [super init];
    if (!self)
        return nil;

    self.owner = owner;
    self.boundObject = boundObject;

    m_ownerKeyPath = [ownerKeyPath copy];
    m_boundKeyPath = [boundKeyPath copy];

    __weak PROBinding *weakSelf = self;

    self.ownerObserver = [[PROKeyValueObserver alloc]
        initWithTarget:owner
        keyPath:ownerKeyPath
        block:^(NSDictionary *changes){
            // ignore changes triggered by ourself
            if (weakSelf.updating)
                return;

            weakSelf.updating = YES;
            @onExit {
                weakSelf.updating = NO;
            };

            [weakSelf ownerChanged:weakSelf];
        }
    ];

    self.boundObjectObserver = [[PROKeyValueObserver alloc]
        initWithTarget:boundObject
        keyPath:boundKeyPath
        options:NSKeyValueObservingOptionInitial
        block:^(NSDictionary *changes){
            // ignore changes triggered by ourself
            if (weakSelf.updating)
                return;

            weakSelf.updating = YES;
            @onExit {
                weakSelf.updating = NO;
            };

            [weakSelf boundObjectChanged:weakSelf];
        }
    ];

    return self;
}

#pragma mark Unbinding

- (void)unbind {
    self.ownerObserver = nil;
    self.boundObjectObserver = nil;

    id owner = self.owner;
    self.owner = nil;
    self.boundObject = nil;

    NSMutableArray *bindings = objc_getAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey);
    if (!bindings) {
        // must've been torn down already
        return;
    }

    NSUInteger indexOfSelf = [bindings indexOfObjectIdenticalTo:self];
    if (indexOfSelf == NSNotFound)
        return;

    if (bindings.count == 1) {
        // this is the last binding, so destroy the whole array
        objc_setAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        [bindings removeObjectAtIndex:indexOfSelf];
    }
}

+ (void)removeAllBindingsFromOwner:(id)owner; {
    NSParameterAssert(owner);

    NSArray *bindings = objc_getAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey);
    objc_setAssociatedObject(owner, PROBindingOwnerAssociatedBindingsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [bindings makeObjectsPerformSelector:@selector(unbind)];
}

#pragma mark Actions

- (IBAction)ownerChanged:(id)sender; {
    if (!self.bound)
        return;

    id owner = self.owner;
    
    // this is technically checked by the 'bound' property, but weak references
    // can go away at almost any time
    if (!owner)
        return;

    id value = [owner valueForKeyPath:self.ownerKeyPath];
    [self.boundObject setValue:value forKeyPath:self.boundKeyPath];
}

- (IBAction)boundObjectChanged:(id)sender; {
    if (!self.bound)
        return;

    id value = [self.boundObject valueForKeyPath:self.boundKeyPath];
    [self.owner setValue:value forKeyPath:self.ownerKeyPath];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>( bound from \"%@\" on %@ to \"%@\" on %@ )", [self class], self, self.ownerKeyPath, self.owner, self.boundKeyPath, self.boundObject];
}

@end
