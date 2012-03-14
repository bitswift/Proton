//
//  NSObject+EditorAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSObject+EditorAdditions.h"
#import "EXTSafeCategory.h"
#import <objc/runtime.h>

@safecategory (NSObject, EditorAdditions)

#pragma mark Properties

- (NSString *)editingUndoActionName {
    return objc_getAssociatedObject(self, @selector(editingUndoActionName));
}

- (void)setEditingUndoActionName:(NSString *)name {
    objc_setAssociatedObject(self, @selector(editingUndoActionName), name, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
