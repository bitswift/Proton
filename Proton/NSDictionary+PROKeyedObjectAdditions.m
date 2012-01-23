//
//  NSDictionary+PROKeyedObjectAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "NSDictionary+PROKeyedObjectAdditions.h"
#import "EXTSafeCategory.h"
#import <objc/runtime.h>

@safecategory (NSDictionary, PROKeyedObjectAdditions)

#pragma mark Category loading

+ (void)load {
    // manually add <PROKeyedObject> conformance to NSDictionary, since the
    // category alone doesn't do it
    class_addProtocol([NSDictionary class], @protocol(PROKeyedObject));
}

- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    return [self initWithDictionary:dictionary];
}

#pragma mark PROKeyedObject

- (NSDictionary *)dictionaryValue {
    // return an immutable snapshot, in case self is mutable
    return [self copy];
}

@end
