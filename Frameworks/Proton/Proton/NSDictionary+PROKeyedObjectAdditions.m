//
//  NSDictionary+PROKeyedObjectAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/NSDictionary+PROKeyedObjectAdditions.h>
#import <Proton/EXTSafeCategory.h>

@safecategory (NSDictionary, PROKeyedObjectAdditions)
- (NSDictionary *)dictionaryValue {
    // return an immutable snapshot, in case self is mutable
    return [self copy];
}
@end
