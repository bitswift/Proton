//
//  NSObject+KeyValueCodingAdditions.m
//  Proton
//
//  Created by Justin Spahr-Summers on 02.03.12.
//  Copyright (c) 2012 Bitswift. All rights reserved.
//

#import "NSObject+KeyValueCodingAdditions.h"
#import "EXTSafeCategory.h"

@safecategory (NSObject, KeyValueCodingAdditions)

- (void)applyKeyValueChangeDictionary:(NSDictionary *)changes toKeyPath:(NSString *)keyPath mappingNewObjectsUsingBlock:(id (^)(id))block;{ 
    // TODO
}

@end
