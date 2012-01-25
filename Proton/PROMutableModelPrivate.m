//
//  PROMutableModelPrivate.m
//  Proton
//
//  Created by Justin Spahr-Summers on 24.01.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "PROMutableModelPrivate.h"
#import <objc/runtime.h>

#if __has_feature(objc_arc)
#error "ARC should not be enabled when compiling this file."
#endif

@implementation PROMutableModel (Private)

+ (Class)createClass:(NSString *)className superclass:(Class)superclass usingBlock:(void (^)(Class newClass))block; {
    Class newClass = objc_allocateClassPair(superclass, [className UTF8String], 0);
    if (!newClass) {
        return nil;
    }

    block(newClass);
    objc_registerClassPair(newClass);

    return newClass;
}

@end
