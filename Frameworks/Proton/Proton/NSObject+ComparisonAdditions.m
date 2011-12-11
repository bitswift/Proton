//
//  NSObject+ComparisonAdditions.m
//  Proton
//
//  Created by James Lawton on 12/6/11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSObject+ComparisonAdditions.h>

BOOL NSEqualObjects(id obj1, id obj2) {
    return (obj1 == obj2 || [obj1 isEqual:obj2]);
}
